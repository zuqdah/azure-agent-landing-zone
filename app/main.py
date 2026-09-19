"""Sample agent API for the Azure agent landing zone.

The app calls a model deployment through API Management and never talks to
Azure OpenAI directly. It holds no model credentials: its gateway key arrives
as a Container Apps secret resolved from Key Vault, and the gateway
authenticates to the model with its own managed identity.
"""

import os
from dataclasses import dataclass

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

MAX_INPUT_CHARS = 2000

SYSTEM_PROMPT = (
    "You are a concise assistant in an infrastructure engineering lab. "
    "Answer in a few short paragraphs at most."
)


@dataclass(frozen=True)
class Settings:
    endpoint: str
    deployment: str
    api_key: str
    max_output_tokens: int
    reasoning_effort: str

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            endpoint=os.environ["OPENAI_ENDPOINT"].rstrip("/"),
            deployment=os.environ["OPENAI_DEPLOYMENT"],
            api_key=os.environ["OPENAI_API_KEY"],
            max_output_tokens=int(os.environ.get("MAX_OUTPUT_TOKENS", "300")),
            reasoning_effort=os.environ.get("REASONING_EFFORT", "none"),
        )

    @property
    def chat_url(self) -> str:
        # The v1 API: no dated api-version, and the deployment is named in the
        # request body rather than the path.
        return f"{self.endpoint}/openai/v1/chat/completions"


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=MAX_INPUT_CHARS)


class Usage(BaseModel):
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


class ChatResponse(BaseModel):
    reply: str
    finish_reason: str | None
    usage: Usage


app = FastAPI(title="Agent landing zone sample API", version="1.0.0")


def send_chat(settings: Settings, message: str) -> httpx.Response:
    """POST one chat completion to the gateway. Replaced in tests."""
    return httpx.post(
        settings.chat_url,
        headers={"api-key": settings.api_key},
        json={
            "model": settings.deployment,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": message},
            ],
            # Every request is capped, so the gateway's call quota also
            # bounds worst-case token spend. For reasoning models this cap
            # covers reasoning tokens as well as the visible answer.
            "max_completion_tokens": settings.max_output_tokens,
            "reasoning_effort": settings.reasoning_effort,
        },
        timeout=60.0,
    )


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/")
def info() -> dict:
    settings = Settings.from_env()
    return {
        "service": "agent-landing-zone sample API",
        "deployment": settings.deployment,
        "gateway": httpx.URL(settings.endpoint).host,
        "max_output_tokens": settings.max_output_tokens,
        "reasoning_effort": settings.reasoning_effort,
        "try": 'POST /chat {"message": "..."}',
    }


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    settings = Settings.from_env()

    try:
        upstream = send_chat(settings, request.message)
    except httpx.HTTPError:
        raise HTTPException(status_code=502, detail="The model gateway couldn't be reached.")

    # The gateway returns 429 for the per-minute rate limit and 403 once the
    # daily quota is spent. Both mean "try later", not "you're not allowed".
    if upstream.status_code in (403, 429):
        retry_after = upstream.headers.get("Retry-After")
        raise HTTPException(
            status_code=429,
            detail="Lab usage limit reached. Try again later.",
            headers={"Retry-After": retry_after} if retry_after else None,
        )
    if upstream.status_code >= 400:
        raise HTTPException(status_code=502, detail="The model gateway returned an error.")

    body = upstream.json()
    choice = body["choices"][0]
    return ChatResponse(
        # A reasoning model that exhausts its token cap while thinking returns
        # no visible content and finish_reason "length".
        reply=choice["message"].get("content") or "",
        finish_reason=choice.get("finish_reason"),
        usage=Usage(**{k: body["usage"][k] for k in Usage.model_fields}),
    )
