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
os.environ["ALLOW_CAPTCHA_BYPASS"] = "true"
os.environ["UPSTASH_REDIS_REST_URL"] = "https://test-upstash.upstash.io"
os.environ["UPSTASH_REDIS_REST_TOKEN"] = "test-token"

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


# --- Module level: env vars ---

def test_allowed_origin_env_var_set():
    assert os.environ.get("ALLOWED_ORIGIN") == "https://ekyputrapratama.com"

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

def test_rejects_origin_substring_bypass_different_tld():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com.evil.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.FORBIDDEN

def test_rejects_origin_substring_bypass_query_param():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://evil.com?q=https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.FORBIDDEN

def test_accepts_allowed_origin_with_path():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com", "referer": "https://ekyputrapratama.com/page"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.OK

def test_rejects_www_subdomain_of_allowed():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://www.ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.OK

# --- Rate limiting ---

class _FakeResponse:
    def __init__(self, data):
        self._data = data
    def read(self):
        return json.dumps(self._data).encode()
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass


def _make_fake_urlopen(incr_result, expire_ok=True):
    def fake_urlopen(req, timeout=None):
        url = req.full_url
        if "/incr/" in url:
            return _FakeResponse({"result": incr_result})
        elif "/expire/" in url:
            if not expire_ok:
                raise OSError("expire failed")
            return _FakeResponse({"result": 1})
        raise OSError("unexpected URL")
    return fake_urlopen


def test_rate_limit_allows_first_request():
    with patch.object(handler.urllib.request, "urlopen", _make_fake_urlopen(1)):
        assert handler._rate_limit("1.2.3.4") is True


def test_rate_limit_allows_at_boundary():
    with patch.object(handler.urllib.request, "urlopen", _make_fake_urlopen(5)):
        assert handler._rate_limit("1.2.3.4") is True


def test_rate_limit_rejects_after_5_requests():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.2.3.4", "origin": "https://ekyputrapratama.com"},
    )
    with patch.object(handler.urllib.request, "urlopen", _make_fake_urlopen(6)):
        resp = handler.handler(event, None)
        body, status = parse_response(resp)
        assert status == HTTPStatus.TOO_MANY_REQUESTS


def test_rate_limit_calls_expire_on_every_request():
    expire_called = [False]

    def tracking_urlopen(req, timeout=None):
        if "/expire/" in req.full_url:
            expire_called[0] = True
            return _FakeResponse({"result": 1})
        return _FakeResponse({"result": 3})

    with patch.object(handler.urllib.request, "urlopen", tracking_urlopen):
        handler._rate_limit("1.2.3.4")
    assert expire_called[0] is True


def test_rate_limit_fail_open_on_redis_error():
    def error_urlopen(req, timeout=None):
        raise OSError("connection refused")

    with patch.object(handler.urllib.request, "urlopen", error_urlopen):
        assert handler._rate_limit("1.2.3.4") is True


def test_upstash_env_vars_set():
    assert os.environ.get("UPSTASH_REDIS_REST_URL") == "https://test-upstash.upstash.io"
    assert os.environ.get("UPSTASH_REDIS_REST_TOKEN") == "test-token"


def test_rate_limit_allows_when_upstash_not_configured():
    prev = handler.UPSTASH_REDIS_REST_URL
    handler.UPSTASH_REDIS_REST_URL = ""
    with patch.object(handler.urllib.request, "urlopen") as mock_urlopen:
        assert handler._rate_limit("1.2.3.4") is True
        mock_urlopen.assert_not_called()
    handler.UPSTASH_REDIS_REST_URL = prev


def test_rate_limit_uses_request_context_ip_not_spoofed_header():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.2.3.4, 10.0.0.1", "origin": "https://ekyputrapratama.com"},
    )
    event["requestContext"] = {"http": {"sourceIp": "5.6.7.8"}}
    with patch.object(handler.urllib.request, "urlopen", _make_fake_urlopen(1)):
        resp = handler.handler(event, None)
        assert parse_response(resp)[1] == HTTPStatus.OK
    with patch.object(handler.urllib.request, "urlopen", _make_fake_urlopen(6)):
        resp = handler.handler(event, None)
        body, status = parse_response(resp)
        assert status == HTTPStatus.TOO_MANY_REQUESTS


def test_rate_limit_falls_back_to_x_forwarded_for():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"x-forwarded-for": "1.1.1.1", "origin": "https://ekyputrapratama.com"},
    )
    with patch.object(handler.urllib.request, "urlopen", _make_fake_urlopen(1)):
        resp = handler.handler(event, None)
        assert parse_response(resp)[1] == HTTPStatus.OK

# --- Captcha bypass security gate ---

def test_dev_bypass_blocked_when_not_allowed():
    prev = os.environ.pop("ALLOW_CAPTCHA_BYPASS", None)
    spec3 = importlib.util.spec_from_file_location("lam3", os.path.join(os.path.dirname(__file__), "lambda.py"))
    lam3 = importlib.util.module_from_spec(spec3)
    with patch.dict(sys.modules, {"boto3": fake_boto3}):
        spec3.loader.exec_module(lam3)
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = lam3.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Captcha verification failed" in body.get("error", "")
    if prev is not None:
        os.environ["ALLOW_CAPTCHA_BYPASS"] = prev

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

def test_rejects_name_too_long():
    event = api_event(
        {"name": "A" * 201, "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Name too long" in body.get("error", "")

def test_rejects_email_too_long():
    event = api_event(
        {"name": "T", "email": "a" * 250 + "@b.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Email too long" in body.get("error", "")

def test_rejects_mobile_too_long():
    event = api_event(
        {"name": "T", "email": "t@t.com", "mobile": "1" * 51, "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Mobile too long" in body.get("error", "")

def test_rejects_message_too_long():
    event = api_event(
        {"name": "T", "email": "t@t.com", "message": "X" * 10001, "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Message too long" in body.get("error", "")

def test_strips_crlf_from_mobile():
    event = api_event(
        {"name": "T", "email": "t@t.com", "mobile": "+61\r\n400", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.OK
    assert body.get("success") is True

def test_strips_crlf_from_name():
    event = api_event(
        {"name": "Test\r\nUser", "email": "t@t.com", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.OK
    assert body.get("success") is True

def test_rejects_mobile_with_letters():
    event = api_event(
        {"name": "T", "email": "t@t.com", "mobile": "hello world", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST
    assert "Invalid mobile" in body.get("error", "")

def test_accepts_valid_mobile():
    event = api_event(
        {"name": "T", "email": "t@t.com", "mobile": "+61 400 000 000", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.OK
    assert body.get("success") is True

def test_empty_mobile_passes():
    event = api_event(
        {"name": "T", "email": "t@t.com", "mobile": "", "message": "hi", "hcaptcha_token": "dev-bypass"},
        headers={"origin": "https://ekyputrapratama.com"},
    )
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.OK
    assert body.get("success") is True

def test_rejects_invalid_json():
    event = {"headers": {"origin": "https://ekyputrapratama.com"}, "body": "not json"}
    response = handler.handler(event, None)
    body, status = parse_response(response)
    assert status == HTTPStatus.BAD_REQUEST

# --- HTML escaping ---

def test_escapes_html():
    assert handler._esc("<script>alert('xss')</script>") == \
        "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;"
