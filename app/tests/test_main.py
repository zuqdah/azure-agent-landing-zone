import httpx
import pytest
from fastapi.testclient import TestClient

import main


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("OPENAI_ENDPOINT", "https://apim-test.azure-api.net/")
    monkeypatch.setenv("OPENAI_DEPLOYMENT", "chat")
    monkeypatch.setenv("OPENAI_API_VERSION", "2024-10-21")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("MAX_OUTPUT_TOKENS", "123")


@pytest.fixture
def client():
    return TestClient(main.app)


def fake_upstream(monkeypatch, status=200, json=None, headers=None, raises=None):
    """Replace the gateway call and record what the app sent."""
    sent = {}

    def _send(settings, message):
        sent["settings"] = settings
        sent["message"] = message
        if raises:
            raise raises
        request = httpx.Request("POST", settings.chat_url)
        return httpx.Response(status, json=json, headers=headers, request=request)

    monkeypatch.setattr(main, "send_chat", _send)
    return sent


COMPLETION = {
    "choices": [{"message": {"role": "assistant", "content": "Hello from the lab."}}],
    "usage": {"prompt_tokens": 30, "completion_tokens": 6, "total_tokens": 36},
}


def test_healthz(client):
    assert client.get("/healthz").json() == {"status": "ok"}


def test_info_exposes_gateway_host_only(client):
    body = client.get("/").json()
    assert body["gateway"] == "apim-test.azure-api.net"
    assert "test-key" not in str(body)


def test_chat_returns_reply_and_usage(client, monkeypatch):
    sent = fake_upstream(monkeypatch, json=COMPLETION)

    response = client.post("/chat", json={"message": "hi"})

    assert response.status_code == 200
    assert response.json() == {
        "reply": "Hello from the lab.",
        "usage": {"prompt_tokens": 30, "completion_tokens": 6, "total_tokens": 36},
    }
    assert sent["message"] == "hi"
    assert sent["settings"].max_output_tokens == 123


def test_chat_url_targets_gateway_deployment():
    settings = main.Settings.from_env()
    assert settings.chat_url == "https://apim-test.azure-api.net/openai/deployments/chat/chat/completions"


@pytest.mark.parametrize("message", ["", "x" * (main.MAX_INPUT_CHARS + 1)])
def test_chat_rejects_empty_and_oversized_input(client, monkeypatch, message):
    sent = fake_upstream(monkeypatch, json=COMPLETION)

    response = client.post("/chat", json={"message": message})

    assert response.status_code == 422
    assert sent == {}, "invalid input must never reach the gateway"


@pytest.mark.parametrize("status", [403, 429])
def test_gateway_limits_become_429(client, monkeypatch, status):
    fake_upstream(monkeypatch, status=status, json={"statusCode": status}, headers={"Retry-After": "42"})

    response = client.post("/chat", json={"message": "hi"})

    assert response.status_code == 429
    assert response.headers["Retry-After"] == "42"


def test_other_gateway_errors_become_502(client, monkeypatch):
    fake_upstream(monkeypatch, status=500, json={"error": "internal detail"})

    response = client.post("/chat", json={"message": "hi"})

    assert response.status_code == 502
    assert "internal detail" not in response.text


def test_unreachable_gateway_becomes_502(client, monkeypatch):
    fake_upstream(monkeypatch, raises=httpx.ConnectError("boom"))

    response = client.post("/chat", json={"message": "hi"})

    assert response.status_code == 502
