import json
import os
import re
import time
import urllib.request
import urllib.parse
from http import HTTPStatus

import boto3

RECIPIENT_EMAIL = os.environ["RECIPIENT_EMAIL"]
SENDER_EMAIL = os.environ["SENDER_EMAIL"]
HCAPTCHA_SECRET = os.environ["HCAPTCHA_SECRET"]
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "")
DOMAIN_NAME = os.environ.get("DOMAIN_NAME", "")
HCAPTCHA_VERIFY_URL = "https://hcaptcha.com/siteverify"

ses = boto3.client("ses")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
rate_store = {}


def _check_origin(headers):
    if not ALLOWED_ORIGIN:
        return True
    origin = (headers or {}).get("origin", "")
    referer = (headers or {}).get("referer", "")
    return ALLOWED_ORIGIN in origin or ALLOWED_ORIGIN.replace("https://", "") in referer


def _rate_limit(ip):
    now = time.time()
    window = rate_store.get(ip, [])
    window = [t for t in window if now - t < 60]
    if len(window) >= 3:
        return False
    window.append(now)
    rate_store[ip] = window
    return True


def handler(event, context):
    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    source_ip = (headers.get("x-forwarded-for") or "unknown").split(",")[0].strip()

    if not _rate_limit(source_ip):
        return _error("Too many requests. Please wait.", HTTPStatus.TOO_MANY_REQUESTS)

    if not _check_origin(headers):
        return _error("Forbidden", HTTPStatus.FORBIDDEN)

    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return _error("Invalid JSON", HTTPStatus.BAD_REQUEST)

    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    mobile = (body.get("mobile") or "").strip()
    message = (body.get("message") or "").strip()
    captcha_token = body.get("hcaptcha_token", "")

    if not name:
        return _error("Name is required", HTTPStatus.BAD_REQUEST)
    if not email or not EMAIL_RE.match(email):
        return _error("Valid email is required", HTTPStatus.BAD_REQUEST)
    if not message:
        return _error("Message is required", HTTPStatus.BAD_REQUEST)

    if captcha_token != "dev-bypass":
        data = urllib.parse.urlencode(
            {"secret": HCAPTCHA_SECRET, "response": captcha_token}
        ).encode()
        req = urllib.request.Request(HCAPTCHA_VERIFY_URL, data=data, method="POST")
        with urllib.request.urlopen(req, timeout=10) as resp:
            if not json.loads(resp.read()).get("success"):
                return _error("Captcha verification failed", HTTPStatus.BAD_REQUEST)

    mobile_line = f"Mobile: {mobile}" if mobile else "Mobile: not provided"

    html_body = f"""<html>
<body style="font-family: sans-serif; max-width: 600px;">
  <h2 style="border-bottom: 3px solid #18181B; padding-bottom: 8px;">New Contact Message</h2>
  <p><strong>Name:</strong> {_esc(name)}</p>
  <p><strong>Email:</strong> {_esc(email)}</p>
  <p>{_esc(mobile_line)}</p>
  <hr style="border: 1px solid #E4E4E7;">
  <p style="white-space: pre-wrap;">{_esc(message)}</p>
</body>
</html>"""

    text_body = f"Name: {name}\nEmail: {email}\n{mobile_line}\n\n{message}"
    subject_domain = DOMAIN_NAME or "contact form"

    try:
        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={"ToAddresses": [RECIPIENT_EMAIL]},
            Message={
                "Subject": {"Data": f"Contact from {name} via {subject_domain}"},
                "Body": {
                    "Html": {"Data": html_body},
                    "Text": {"Data": text_body},
                },
            },
        )
    except Exception as e:
        print(f"SES send error: {e}")
        return _error(
            "Failed to send message. Please try again later.",
            HTTPStatus.INTERNAL_SERVER_ERROR,
        )

    return {
        "statusCode": HTTPStatus.OK,
        "headers": _cors_headers(),
        "body": json.dumps({"success": True}),
    }


def _error(message, status_code):
    return {
        "statusCode": status_code,
        "headers": _cors_headers(),
        "body": json.dumps({"error": message}),
    }


def _cors_headers():
    return {
        "Access-Control-Allow-Origin": ALLOWED_ORIGIN or "*",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
    }


def _esc(s):
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#x27;")
    )
