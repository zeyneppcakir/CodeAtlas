from fastapi import APIRouter, HTTPException

from app.models.repo_models import RepoRequest
from app.services.github_service import (
    analyze_repo_code,
    get_repo_files,
    get_repo_info,
    get_repo_tree,
)

router = APIRouter(prefix="/github", tags=["GitHub"])


def _handle_service_call(service_fn, repo_url: str):
    try:
        return service_fn(repo_url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Beklenmeyen bir hata oluştu: {str(e)}",
        )


@router.post("/import")
def import_repo(data: RepoRequest):
    return _handle_service_call(get_repo_info, data.repo_url)


@router.post("/files")
def repo_files(data: RepoRequest):
    return _handle_service_call(get_repo_files, data.repo_url)


@router.post("/scan")
def scan_repo(data: RepoRequest):
    return _handle_service_call(get_repo_tree, data.repo_url)


@router.post("/analyze")
def analyze_repo(data: RepoRequest):
    try:
        return analyze_repo_code(
            repo_url=data.repo_url,
            run_llm=False
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Analiz sırasında hata oluştu: {str(e)}",
        )


@router.post("/analyze-with-llm")
def analyze_repo_with_llm(data: RepoRequest):
    try:
        return analyze_repo_code(
            repo_url=data.repo_url,
            run_llm=True
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"LLM analizi sırasında hata oluştu: {str(e)}",
        )