from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.services.llm_service import analyze_with_llm

router = APIRouter(prefix="/llm", tags=["llm"])


class LLMRequest(BaseModel):
    prompt: str = Field(..., description="Modele gönderilecek prompt")
    provider: Optional[str] = Field(
        default=None,
        description="LLM provider adı. Örn: gemini veya ollama"
    )
    model: Optional[str] = Field(
        default=None,
        description="Kullanılacak model adı. Örn: gemini-2.5-flash, deepseek-coder, qwen2.5-coder:3b, minimax-m2:cloud"
    )


class LLMResponse(BaseModel):
    provider: str
    model: str
    output: str


@router.post("/generate", response_model=LLMResponse)
def generate(request: LLMRequest):
    try:
        if not request.prompt or not request.prompt.strip():
            raise HTTPException(status_code=400, detail="Prompt boş olamaz.")

        result = analyze_with_llm(
            prompt=request.prompt.strip(),
            provider=request.provider.strip() if request.provider else None,
            model=request.model.strip() if request.model else None,
        )

        return LLMResponse(
            provider=result["provider"],
            model=result["model"],
            output=result["output"],
        )

    except HTTPException:
        raise

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"LLM error: {str(e)}"
        )