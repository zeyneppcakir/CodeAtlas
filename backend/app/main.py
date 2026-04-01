from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.github import router as github_router
from app.routes.llm import router as llm_router
from app.routes.cloc import router as cloc_router

app = FastAPI(title="CodeAtlas Backend")

# CORS ayarı (Flutter Web için gerekli)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):[0-9]+",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "CodeAtlas backend çalışıyor"}

@app.get("/health")
def health():
    return {"status": "ok"}

# GitHub analiz router
app.include_router(github_router)

# LLM router
app.include_router(llm_router)

# CLOC router
app.include_router(cloc_router)