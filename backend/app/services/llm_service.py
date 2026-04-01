import os
from typing import Optional

import httpx
from dotenv import load_dotenv
from google import genai

load_dotenv()


class LLMService:
    def __init__(self):
        self.gemini_api_key = os.getenv("GEMINI_API_KEY", "")
        self.ollama_base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

        self.default_provider = os.getenv("DEFAULT_PROVIDER", "gemini")
        self.default_gemini_model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        self.default_ollama_model = os.getenv("OLLAMA_MODEL", "qwen2.5:3b")

        self.gemini_client = None
        if self.gemini_api_key:
            self.gemini_client = genai.Client(api_key=self.gemini_api_key)

    def generate(
        self,
        prompt: str,
        provider: Optional[str] = None,
        model: Optional[str] = None,
    ) -> dict:
        if not prompt or not prompt.strip():
            raise ValueError("Prompt boş olamaz.")

        selected_provider = (provider or self.default_provider).lower().strip()

        if selected_provider == "gemini":
            return self._generate_with_gemini(prompt, model)
        elif selected_provider == "ollama":
            return self._generate_with_ollama(prompt, model)
        else:
            raise ValueError(f"Desteklenmeyen provider: {selected_provider}")

    def _generate_with_gemini(
        self,
        prompt: str,
        model: Optional[str] = None,
    ) -> dict:
        if not self.gemini_client:
            raise ValueError("GEMINI_API_KEY bulunamadı.")

        selected_model = model or self.default_gemini_model

        try:
            response = self.gemini_client.models.generate_content(
                model=selected_model,
                contents=prompt
            )
            output = response.text if hasattr(response, "text") and response.text else ""
        except Exception as e:
            raise ValueError(f"Gemini isteği başarısız oldu: {str(e)}")

        return {
            "provider": "gemini",
            "model": selected_model,
            "output": output.strip()
        }

    def _generate_with_ollama(
        self,
        prompt: str,
        model: Optional[str] = None,
    ) -> dict:
        selected_model = model or self.default_ollama_model

        payload = {
            "model": selected_model,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "stream": False
        }

        try:
            with httpx.Client(timeout=120.0) as client:
                response = client.post(
                    f"{self.ollama_base_url}/api/chat",
                    json=payload
                )
                response.raise_for_status()
                data = response.json()
        except httpx.ConnectError:
            raise ValueError("Ollama servisine bağlanılamadı. Ollama açık mı kontrol et.")
        except httpx.HTTPStatusError as e:
            raise ValueError(f"Ollama HTTP hatası: {e.response.status_code} - {e.response.text}")
        except Exception as e:
            raise ValueError(f"Ollama isteği başarısız oldu: {str(e)}")

        output = data.get("message", {}).get("content", "")

        return {
            "provider": "ollama",
            "model": selected_model,
            "output": output.strip()
        }


llm_service = LLMService()


def analyze_with_llm(
    prompt: str,
    provider: Optional[str] = None,
    model: Optional[str] = None,
):
    return llm_service.generate(prompt=prompt, provider=provider, model=model)


def analyze_with_gemini(prompt: str):
    return llm_service.generate(prompt=prompt, provider="gemini")