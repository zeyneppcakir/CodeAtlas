import base64
import requests

from app.services.llm_service import analyze_with_gemini


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


def get_repo_info(repo_url: str):
    owner, repo = parse_github_url(repo_url)

    github_api_url = f"https://api.github.com/repos/{owner}/{repo}"
    response = requests.get(github_api_url, timeout=15)

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
    }


def get_repo_files(repo_url: str):
    owner, repo = parse_github_url(repo_url)

    api_url = f"https://api.github.com/repos/{owner}/{repo}/contents"
    response = requests.get(api_url, timeout=15)

    if response.status_code != 200:
        raise ValueError("Repo dosyaları alınamadı.")

    files = response.json()

    code_extensions = [
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

    code_files = []

    for file in files:
        if file.get("type") == "file":
            name = file.get("name", "")

            for ext in code_extensions:
                if name.endswith(ext):
                    code_files.append(
                        {
                            "name": name,
                            "type": file.get("type"),
                            "path": file.get("path"),
                        }
                    )
                    break

    return {
        "repo": repo,
        "code_files_found": len(code_files),
        "files": code_files,
    }


def get_repo_tree(repo_url: str):
    owner, repo = parse_github_url(repo_url)

    api_url = f"https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1"
    response = requests.get(api_url, timeout=20)

    if response.status_code != 200:
        raise ValueError("Repo tree alınamadı.")

    data = response.json()

    code_extensions = [
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

    code_files = []

    for file in data.get("tree", []):
        if file.get("type") == "blob":
            path = file.get("path", "")

            for ext in code_extensions:
                if path.endswith(ext):
                    code_files.append(path)
                    break

    return {
        "repo": repo,
        "total_files_scanned": len(data.get("tree", [])),
        "code_files_found": len(code_files),
        "files": code_files[:50],
    }


def detect_language_from_path(path: str):
    extension_map = {
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

    for ext, language in extension_map.items():
        if path.endswith(ext):
            return language

    return "Unknown"


def get_code_file_paths(owner: str, repo: str):
    api_url = f"https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1"
    response = requests.get(api_url, timeout=20)

    if response.status_code != 200:
        raise ValueError("Repo tree alınamadı.")

    data = response.json()

    code_extensions = [
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

    code_files = []

    for file in data.get("tree", []):
        if file.get("type") == "blob":
            path = file.get("path", "")
            for ext in code_extensions:
                if path.endswith(ext):
                    code_files.append(path)
                    break

    return code_files


def get_file_content(owner: str, repo: str, path: str):
    api_url = f"https://api.github.com/repos/{owner}/{repo}/contents/{path}"
    response = requests.get(api_url, timeout=20)

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

Cevabın düzenli ve anlaşılır olsun.

Kodlar:
{combined_code}
"""
    return prompt


def analyze_repo_code(repo_url: str, max_files: int = 10):
    owner, repo = parse_github_url(repo_url)

    code_paths = get_code_file_paths(owner, repo)
    selected_paths = code_paths[:max_files]

    total_lines = 0
    non_empty_lines = 0
    todo_count = 0
    fixme_count = 0
    hack_count = 0
    bug_count = 0
    analyzed_files = 0
    language_distribution = {}

    file_summaries = []
    llm_input_files = []

    for path in selected_paths:
        content = get_file_content(owner, repo, path)

        if not content:
            continue

        analyzed_files += 1

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
            llm_analysis = analyze_with_gemini(prompt)
        except Exception as e:
            llm_error = f"Gemini analizi sırasında hata oluştu: {str(e)}"

    return {
        "repo": repo,
        "total_code_files_found": len(code_paths),
        "analyzed_files": analyzed_files,
        "max_files_limit": max_files,
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