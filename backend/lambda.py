import json
import os
import re
import time
import urllib.request
import urllib.parse
from http import HTTPStatus
from urllib.parse import urlparse

import boto3

RECIPIENT_EMAIL = os.environ["RECIPIENT_EMAIL"]
SENDER_EMAIL = os.environ["SENDER_EMAIL"]
HCAPTCHA_SECRET = os.environ["HCAPTCHA_SECRET"]
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "")
DOMAIN_NAME = os.environ.get("DOMAIN_NAME", "")
ALLOW_CAPTCHA_BYPASS = os.environ.get("ALLOW_CAPTCHA_BYPASS", "") == "true"
HCAPTCHA_VERIFY_URL = "https://hcaptcha.com/siteverify"

ses = boto3.client("ses")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
rate_store = {}


def _check_origin(headers):
    if not ALLOWED_ORIGIN:
        return True
    allowed = urlparse(ALLOWED_ORIGIN)
    origin = urlparse((headers or {}).get("origin", ""))
    if not origin.netloc:
        return False
    allowed_netloc = allowed.netloc.removeprefix("www.")
    origin_netloc = origin.netloc.removeprefix("www.")
    return origin.scheme == allowed.scheme and origin_netloc == allowed_netloc


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
    source_ip = (
        event.get("requestContext", {}).get("http", {}).get("sourceIp")
        or (headers.get("x-forwarded-for") or "unknown").split(",")[0].strip()
    )

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

    if len(name) > 200:
        return _error("Name too long", HTTPStatus.BAD_REQUEST)
    if len(email) > 254:
        return _error("Email too long", HTTPStatus.BAD_REQUEST)
    if len(mobile) > 50:
        return _error("Mobile too long", HTTPStatus.BAD_REQUEST)
    if len(message) > 10000:
        return _error("Message too long", HTTPStatus.BAD_REQUEST)

    name = re.sub(r"[\r\n\t]", " ", name)

    if not (ALLOW_CAPTCHA_BYPASS and captcha_token == "dev-bypass"):
        data = urllib.parse.urlencode(
            {"secret": HCAPTCHA_SECRET, "response": captcha_token}
        ).encode()
        req = urllib.request.Request(HCAPTCHA_VERIFY_URL, data=data, method="POST")
        with urllib.request.urlopen(req, timeout=10) as resp:
            if not json.loads(resp.read()).get("success"):
                return _error("Captcha verification failed", HTTPStatus.BAD_REQUEST)

    mobile_line = f"Mobile: {mobile}" if mobile else "Mobile: not provided"
    subject_domain = DOMAIN_NAME or "contact form"
    from_addr = f"Eky Pratama Portfolio <{SENDER_EMAIL}>"

    html_body = f"""<html>
<body style="font-family: sans-serif; max-width: 600px; color: #18181B;">
  <h2 style="border-bottom: 3px solid #18181B; padding-bottom: 8px;">New Message from {_esc(name)}</h2>
  <p><strong>Name:</strong> {_esc(name)}</p>
  <p><strong>Email:</strong> {_esc(email)}</p>
  <p>{_esc(mobile_line)}</p>
  <hr style="border: 1px solid #E4E4E7;">
  <p style="white-space: pre-wrap;">{_esc(message)}</p>
  <hr style="border: 1px solid #E4E4E7;">
  <p style="font-size: 12px; color: #71717A;">Sent via contact form at {_esc(subject_domain)}</p>
</body>
</html>"""

    text_body = f"Name: {name}\nEmail: {email}\n{mobile_line}\n\n{message}\n\n--\nSent via contact form at {subject_domain}"

    try:
        ses.send_email(
            Source=from_addr,
            Destination={"ToAddresses": [RECIPIENT_EMAIL]},
            Message={
                "Subject": {"Data": f"Portfolio contact from {name} via {subject_domain}"},
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
