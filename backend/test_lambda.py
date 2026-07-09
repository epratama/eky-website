import json
import os
import sys
import importlib
from http import HTTPStatus
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, os.path.dirname(__file__))

# Set required env vars
os.environ.setdefault("RECIPIENT_EMAIL", "recipient@test.com")
os.environ.setdefault("SENDER_EMAIL", "sender@test.com")
os.environ.setdefault("HCAPTCHA_SECRET", "test-secret")
os.environ["ALLOWED_ORIGIN"] = "https://ekyputrapratama.com"
os.environ["DOMAIN_NAME"] = "ekyputrapratama.com"

# Mock boto3 before importing lambda (module-level boto3.client call)
fake_ses = MagicMock()
fake_boto3 = MagicMock()
fake_boto3.client.return_value = fake_ses

with patch.dict(sys.modules, {"boto3": fake_boto3}):
    spec = importlib.util.spec_from_file_location("lam", os.path.join(os.path.dirname(__file__), "lambda.py"))
    handler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(handler)


def api_event(body, headers=None):
    return {
        "headers": headers or {},
        "body": json.dumps(body) if isinstance(body, dict) else body,
    }


def parse_response(response):
    return json.loads(response["body"]), response["statusCode"]


@pytest.fixture(autouse=True)
def clear_rate_store():
    handler.rate_store.clear()


# --- Module level: env vars + store ---

def test_allowed_origin_env_var_set():
    assert os.environ.get("ALLOWED_ORIGIN") == "https://ekyputrapratama.com"

def test_rate_store_exists():
    assert hasattr(handler, "rate_store")

# --- Origin validation ---

def test_rejects_request_from_wrong_origin():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://evil.com", "referer": "https://evil.com/page"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.FORBIDDEN
    assert "Forbidden" in body.get("error", "")

def test_accepts_request_from_allowed_origin():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.OK
    assert body.get("success") is True

# --- Rate limiting ---

def test_rate_limit_rejects_after_3_requests():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.2.3.4", "origin": "https://ekyputrapratama.com"},
    )
    for _ in range(3):
        resp = handler.handler(event, None)
        body, status = parse_response(resp)
        assert status == HTTPStatus.OK
    # 4th request should be rate limited
    resp = handler.handler(event, None)
    body, status = parse_response(resp)
    assert status == HTTPStatus.TOO_MANY_REQUESTS

def test_rate_limit_resets_after_window():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.2.3.5", "origin": "https://ekyputrapratama.com"},
    )
    for _ in range(3):
        resp = handler.handler(event, None)
        body, status = parse_response(resp)
        assert status == HTTPStatus.OK
    # Age out the rate window
    old_time = handler.time.time
    handler.time.time = lambda: old_time() + 61
    resp = handler.handler(event, None)
    body, status = parse_response(resp)
    assert status == HTTPStatus.OK
    handler.time.time = old_time

# --- CORS ---

def test_cors_uses_allowed_origin():
    cors = handler._cors_headers()
    assert cors["Access-Control-Allow-Origin"] == "https://ekyputrapratama.com"

def test_cors_falls_back_to_star_when_not_set():
    del os.environ["ALLOWED_ORIGIN"]
    spec2 = importlib.util.spec_from_file_location("lam2", os.path.join(os.path.dirname(__file__), "lambda.py"))
    lam2 = importlib.util.module_from_spec(spec2)
    with patch.dict(sys.modules, {"boto3": fake_boto3}):
        spec2.loader.exec_module(lam2)
    cors = lam2._cors_headers()
    assert cors["Access-Control-Allow-Origin"] == "*"
    os.environ["ALLOWED_ORIGIN"] = "https://ekyputrapratama.com"

# --- Validation (existing behavior must work) ---

def test_rejects_empty_name():
    event = api_event(
        {"name": "", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Name is required" in body.get("error", "")

def test_rejects_invalid_email():
    event = api_event(
        {"name": "T", "email": "notanemail", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Valid email" in body.get("error", "")

def test_rejects_empty_message():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Message is required" in body.get("error", "")

def test_rejects_invalid_json():
    event = {"headers": {"origin": "https://ekyputrapratama.com"}, "body": "not json"}
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST

# --- HTML escaping ---

def test_escapes_html():
    assert handler._esc("<script>alert('xss')</script>") == \
        "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;"
