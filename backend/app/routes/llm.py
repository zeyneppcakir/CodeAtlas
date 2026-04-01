from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.llm_service import analyze_with_llm

router = APIRouter(prefix="/llm", tags=["llm"])


class LLMRequest(BaseModel):
    prompt: str
    provider: Optional[str] = None
    model: Optional[str] = None


class LLMResponse(BaseModel):
    provider: str
    model: str
    output: str


@router.post("/generate", response_model=LLMResponse)
def generate(request: LLMRequest):
    try:
        result = analyze_with_llm(
            prompt=request.prompt,
            provider=request.provider,
            model=request.model
        )
        return result

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"LLM error: {str(e)}")