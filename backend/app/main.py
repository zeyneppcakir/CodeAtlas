from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.github import router as github_router

app = FastAPI(title="CodeAtlas Backend")

# CORS ayarı (Flutter Web için gerekli)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # geliştirme aşamasında tüm originlere izin veriyoruz
    allow_credentials=True,
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