import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_ENDPOINT = "https://genaiapi.shanghaitech.edu.cn/api/v1/start"
DEFAULT_MODEL = "GPT-5.6-SOL"
DEFAULT_TIMEOUT_SECONDS = 120
SYSTEM_PROMPT = (
    "You are an assistant for an fMRI analysis toolbox. "
    "Answer clearly and distinguish verified facts from suggestions. "
    "Do not claim that data processing has run unless execution results are provided."
)


def get_api_config():
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not configured")

    endpoint = os.environ.get("OPENAI_ENDPOINT", DEFAULT_ENDPOINT).strip()
    model = os.environ.get("OPENAI_MODEL", DEFAULT_MODEL).strip()
    timeout_text = os.environ.get("OPENAI_TIMEOUT_SECONDS", str(DEFAULT_TIMEOUT_SECONDS)).strip()
    try:
        timeout = int(timeout_text)
    except ValueError as error:
        raise ValueError("OPENAI_TIMEOUT_SECONDS must be an integer") from error
    if timeout <= 0:
        raise ValueError("OPENAI_TIMEOUT_SECONDS must be positive")
    return api_key, endpoint, model, timeout


def post_chat(messages):
    api_key, endpoint, model, timeout = get_api_config()
    payload = json.dumps(
        {"model": model, "messages": messages},
        ensure_ascii=False,
    ).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"API HTTP {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"API connection failed: {error.reason}") from error

    try:
        result = json.loads(body)
    except json.JSONDecodeError as error:
        raise RuntimeError("The API returned invalid JSON") from error

    try:
        content = result["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as error:
        message = result.get("message") or result.get("error") or body
        raise RuntimeError(f"The API response has no assistant message: {message}") from error

    if content is None:
        raise RuntimeError("The API returned an empty assistant message")
    return content, result.get("model", model)


def process_chat(request):
    query = str(request.get("query", "")).strip()
    if not query:
        raise ValueError("The query is empty")

    error_context = str(request.get("error_context", "")).strip()
    user_content = query
    if error_context:
        user_content = f"{query}\n\nError context:\n{error_context}"

    content, resolved_model = post_chat(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ]
    )
    return {
        "ok": True,
        "type": "message",
        "content": content,
        "model": resolved_model,
    }


def load_request(path):
    with open(path, "r", encoding="utf-8") as stream:
        request = json.load(stream)
    if not isinstance(request, dict):
        raise ValueError("The request must be a JSON object")
    return request


def process_request(request):
    mode = str(request.get("mode", "chat")).lower()
    if mode == "chat":
        return process_chat(request)
    raise ValueError(f"Unsupported request mode: {mode}")


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("legacy_query", nargs="?")
    parser.add_argument("legacy_error", nargs="?")
    parser.add_argument("--request")
    return parser.parse_args()


def main():
    try:
        arguments = parse_arguments()
        if arguments.request:
            request = load_request(arguments.request)
        elif arguments.legacy_query:
            request = {
                "mode": "chat",
                "query": arguments.legacy_query,
                "error_context": arguments.legacy_error or "",
            }
        else:
            raise ValueError("A request file or query is required")

        result = process_request(request)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
