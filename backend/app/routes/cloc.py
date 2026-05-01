from fastapi import APIRouter
import subprocess
import json

router = APIRouter(prefix="/cloc", tags=["CLOC"])

@router.get("/analyze")
def analyze_cloc():
    try:
        result = subprocess.run(
            [".\\cloc-2.08.exe", "..", "--json"],
            capture_output=True,
            text=True,
            cwd="."
        )

        if result.returncode != 0:
            return {
                "status": "error",
                "message": result.stderr or "cloc çalıştırılırken hata oluştu."
            }

        data = json.loads(result.stdout)

        return {
            "status": "success",
            "data": data
        }

    except Exception as e:
        return {
            "status": "error",
            "message": str(e)
        }