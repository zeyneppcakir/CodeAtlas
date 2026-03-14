from fastapi import APIRouter, HTTPException

from app.models.repo_models import RepoRequest
from app.services.github_service import (
    get_repo_info,
    get_repo_files,
    get_repo_tree,
    analyze_repo_code,
)

router = APIRouter(prefix="/github", tags=["GitHub"])


@router.post("/import")
def import_repo(data: RepoRequest):
    try:
        return get_repo_info(data.repo_url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Beklenmeyen bir hata oluştu.")


@router.post("/files")
def repo_files(data: RepoRequest):
    try:
        return get_repo_files(data.repo_url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Beklenmeyen bir hata oluştu.")


@router.post("/scan")
def scan_repo(data: RepoRequest):
    try:
        return get_repo_tree(data.repo_url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Beklenmeyen bir hata oluştu.")


@router.post("/analyze")
def analyze_repo(data: RepoRequest):
    try:
        return analyze_repo_code(data.repo_url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Beklenmeyen bir hata oluştu.")