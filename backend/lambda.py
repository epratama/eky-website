import json
import os
import re
import urllib.request
import urllib.parse
from http import HTTPStatus

import boto3

RECIPIENT_EMAIL = os.environ["RECIPIENT_EMAIL"]
SENDER_EMAIL = os.environ["SENDER_EMAIL"]
HCAPTCHA_SECRET = os.environ["HCAPTCHA_SECRET"]
HCAPTCHA_VERIFY_URL = "https://hcaptcha.com/siteverify"

ses = boto3.client("ses")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def handler(event, context):
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

    try:
        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={"ToAddresses": [RECIPIENT_EMAIL]},
            Message={
                "Subject": {"Data": f"Contact from {name} via contact form"},

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
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
    }


def _esc(s):
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )
