import base64
from typing import Any

import requests

from app.services.llm_service import analyze_with_gemini


GITHUB_TIMEOUT = 20

CODE_EXTENSIONS = [
    ".py",
    ".dart",
    ".js",
    ".ts",
    ".java",
    ".kt",
    ".cpp",
    ".c",
    ".cs",
]

EXTENSION_LANGUAGE_MAP = {
    ".py": "Python",
    ".dart": "Dart",
    ".js": "JavaScript",
    ".ts": "TypeScript",
    ".java": "Java",
    ".kt": "Kotlin",
    ".cpp": "C++",
    ".c": "C",
    ".cs": "C#",
}


def parse_github_url(repo_url: str):
    repo_url = repo_url.strip().rstrip("/")

    if not repo_url.startswith("https://github.com/"):
        raise ValueError("Geçerli bir GitHub repo URL'si girin.")

    parts = repo_url.replace("https://github.com/", "").split("/")

    if len(parts) < 2:
        raise ValueError("Repo URL eksik veya hatalı.")

    owner = parts[0]
    repo = parts[1]

    return owner, repo


def _github_get(url: str):
    response = requests.get(url, timeout=GITHUB_TIMEOUT)
    return response


def _is_code_file(path: str) -> bool:
    path_lower = path.lower()
    return any(path_lower.endswith(ext) for ext in CODE_EXTENSIONS)


def _should_ignore_path(path: str) -> bool:
    normalized = path.replace("\\", "/").lower()

    if normalized.endswith("/.ds_store") or normalized.endswith("thumbs.db"):
        return True

    ignore_contains = [
        "/node_modules/",
        "/build/",
        "/dist/",
        "/.git/",
        "/.dart_tool/",
        "/.idea/",
        "/.vscode/",
        "/.gradle/",
        "/pods/",
        "/deriveddata/",
    ]

    if any(token in normalized for token in ignore_contains):
        return True

    def is_platform_folder(folder: str) -> bool:
        return normalized.startswith(f"{folder}/") or f"/{folder}/" in normalized

    if any(
        is_platform_folder(folder)
        for folder in ["android", "ios", "windows", "linux", "macos"]
    ):
        return True

    return False


def get_repo_info(repo_url: str):
    owner, repo = parse_github_url(repo_url)

    github_api_url = f"https://api.github.com/repos/{owner}/{repo}"
    response = _github_get(github_api_url)

    if response.status_code != 200:
        raise ValueError(
            "GitHub reposu alınamadı. Repo yok, private olabilir ya da URL hatalı olabilir."
        )

    repo_data = response.json()

    return {
        "message": "Repo başarıyla alındı",
        "name": repo_data.get("name"),
        "full_name": repo_data.get("full_name"),
        "description": repo_data.get("description"),
        "default_branch": repo_data.get("default_branch"),
        "owner": repo_data.get("owner", {}).get("login"),
        "html_url": repo_data.get("html_url"),
        "size_kb": repo_data.get("size", 0),
    }


def get_repo_files(repo_url: str):
    owner, repo = parse_github_url(repo_url)

    api_url = f"https://api.github.com/repos/{owner}/{repo}/contents"
    response = _github_get(api_url)

    if response.status_code != 200:
        raise ValueError("Repo dosyaları alınamadı.")

    files = response.json()
    code_files = []

    for file in files:
        if file.get("type") != "file":
            continue

        name = file.get("name", "")
        path = file.get("path", "")

        if _is_code_file(path) and not _should_ignore_path(path):
            code_files.append(
                {
                    "name": name,
                    "type": file.get("type"),
                    "path": path,
                    "size": file.get("size", 0),
                }
            )

    return {
        "repo": repo,
        "code_files_found": len(code_files),
        "files": code_files,
    }


def get_repo_tree(repo_url: str):
    owner, repo = parse_github_url(repo_url)

    api_url = f"https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1"
    response = _github_get(api_url)

    if response.status_code != 200:
        raise ValueError("Repo tree alınamadı.")

    data = response.json()

    code_files = []
    total_bytes = 0

    for file in data.get("tree", []):
        if file.get("type") != "blob":
            continue

        path = file.get("path", "")

        if _should_ignore_path(path):
            continue

        if _is_code_file(path):
            size = int(file.get("size", 0) or 0)
            total_bytes += size
            code_files.append(
                {
                    "path": path,
                    "size": size,
                }
            )

    return {
        "repo": repo,
        "total_files_scanned": len(data.get("tree", [])),
        "code_files_found": len(code_files),
        "total_bytes": total_bytes,
        "files": code_files[:50],
    }


def detect_language_from_path(path: str):
    path_lower = path.lower()

    for ext, language in EXTENSION_LANGUAGE_MAP.items():
        if path_lower.endswith(ext):
            return language

    return "Unknown"


def get_code_file_paths(owner: str, repo: str):
    api_url = f"https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1"
    response = _github_get(api_url)

    if response.status_code != 200:
        raise ValueError("Repo tree alınamadı.")

    data = response.json()
    code_files = []

    for file in data.get("tree", []):
        if file.get("type") != "blob":
            continue

        path = file.get("path", "")

        if _should_ignore_path(path):
            continue

        if _is_code_file(path):
            code_files.append(
                {
                    "path": path,
                    "size": int(file.get("size", 0) or 0),
                }
            )

    return code_files


def get_file_content(owner: str, repo: str, path: str):
    api_url = f"https://api.github.com/repos/{owner}/{repo}/contents/{path}"
    response = _github_get(api_url)

    if response.status_code != 200:
        return None

    data = response.json()
    encoded_content = data.get("content")

    if not encoded_content:
        return None

    try:
        decoded_bytes = base64.b64decode(encoded_content)
        return decoded_bytes.decode("utf-8", errors="ignore")
    except Exception:
        return None


def build_repo_prompt(repo: str, file_contents: list[dict]):
    combined_text_parts = []

    for item in file_contents:
        combined_text_parts.append(
            f"Dosya: {item['path']}\n"
            f"Dil: {item['language']}\n"
            f"İçerik:\n{item['content']}\n"
            f"{'-' * 60}"
        )

    combined_code = "\n".join(combined_text_parts)

    prompt = f"""
Sen deneyimli bir yazılım mimarı ve kod analiz uzmanısın.

Aşağıda "{repo}" adlı GitHub reposundan alınmış bazı kaynak kod dosyaları var.

Bu projeyi analiz et ve SADECE Türkçe cevap ver.

Lütfen şu başlıklarda çıktı üret:
1. Projenin genel amacı
2. Kullanılan teknolojiler ve diller
3. Dikkat çeken önemli dosyalar / modüller
4. Kod kalitesi hakkında kısa yorum
5. Olası riskler veya eksikler
6. Geliştirme için 3 somut öneri

Kurallar:
- Markdown kullanma.
- #, ##, **, ``` ve benzeri işaretler kullanma.
- Yanıt kısa, net ve düzenli olsun.

Kodlar:
{combined_code}
"""
    return prompt


def _extract_llm_output(result: Any):
    if result is None:
        return None

    if isinstance(result, dict):
        output = result.get("output")
        if output is not None:
            return str(output).strip()

    return str(result).strip()


def analyze_repo_code(repo_url: str, max_files: int = 10):
    owner, repo = parse_github_url(repo_url)

    code_files = get_code_file_paths(owner, repo)
    selected_files = code_files[:max_files]

    total_lines = 0
    non_empty_lines = 0
    todo_count = 0
    fixme_count = 0
    hack_count = 0
    bug_count = 0
    analyzed_files = 0
    total_bytes = 0

    language_distribution = {}
    file_summaries = []
    llm_input_files = []

    for file_info in selected_files:
        path = file_info["path"]
        file_size = int(file_info.get("size", 0) or 0)

        content = get_file_content(owner, repo, path)
        if not content:
            continue

        analyzed_files += 1
        total_bytes += file_size

        language = detect_language_from_path(path)
        language_distribution[language] = language_distribution.get(language, 0) + 1

        lines = content.splitlines()
        file_total_lines = len(lines)
        file_non_empty_lines = len([line for line in lines if line.strip()])

        total_lines += file_total_lines
        non_empty_lines += file_non_empty_lines

        file_todo = 0
        file_fixme = 0
        file_hack = 0
        file_bug = 0

        for line in lines:
            upper_line = line.upper()

            if "TODO" in upper_line:
                todo_count += 1
                file_todo += 1
            if "FIXME" in upper_line:
                fixme_count += 1
                file_fixme += 1
            if "HACK" in upper_line:
                hack_count += 1
                file_hack += 1
            if "BUG" in upper_line:
                bug_count += 1
                file_bug += 1

        file_summaries.append(
            {
                "path": path,
                "language": language,
                "size_bytes": file_size,
                "total_lines": file_total_lines,
                "non_empty_lines": file_non_empty_lines,
                "todo": file_todo,
                "fixme": file_fixme,
                "hack": file_hack,
                "bug": file_bug,
            }
        )

        llm_input_files.append(
            {
                "path": path,
                "language": language,
                "content": content[:4000],
            }
        )

    llm_analysis = None
    llm_error = None

    if llm_input_files:
        try:
            prompt = build_repo_prompt(repo, llm_input_files)
            llm_result = analyze_with_gemini(prompt)
            llm_analysis = _extract_llm_output(llm_result)
        except Exception as e:
            llm_error = f"Gemini analizi sırasında hata oluştu: {str(e)}"

    return {
        "repo": repo,
        "total_code_files_found": len(code_files),
        "analyzed_files": analyzed_files,
        "max_files_limit": max_files,
        "total_bytes": total_bytes,
        "total_lines": total_lines,
        "non_empty_lines": non_empty_lines,
        "todo_count": todo_count,
        "fixme_count": fixme_count,
        "hack_count": hack_count,
        "bug_count": bug_count,
        "language_distribution": language_distribution,
        "file_summaries": file_summaries[:20],
        "llm_analysis": llm_analysis,
        "llm_error": llm_error,
    }