import argparse
import json
import os
import re
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

MAX_PLAN_STEPS = 50


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


def build_context_text(context):
    if not context:
        return ""
    try:
        return json.dumps(context, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError):
        return str(context)


def build_tools_text(tools):
    if not tools:
        return ""
    try:
        return json.dumps(tools, ensure_ascii=False, separators=(",", ":"), indent=2)
    except (TypeError, ValueError):
        return str(tools)


def build_agent_messages(request):
    prompt = str(request.get("prompt", "")).strip()
    if not prompt:
        raise ValueError("The agent prompt is empty")

    tools = request.get("tools") or []
    context = request.get("context")
    working_directory = str(request.get("working_directory", "") or "").strip()
    history = request.get("history") or []

    system = (
        "You are the planning engine of an fMRI analysis toolbox. You plan work strictly with the "
        "tools below; you never fabricate results and you never run code yourself.\n"
        "\n"
        "Rules:\n"
        "1. Only a tool with status 'enabled' and execution_mode 'auto' can appear in an executable "
        "plan. Tools with status 'interactive' need a human step and tools with status 'unavailable' "
        "are placeholders or broken - never put them in a plan; instead explain the limitation in a "
        "message.\n"
        "2. Parameters of type 'file' or 'dir' must be absolute paths, or paths relative to the "
        "working directory, and must refer to files/folders listed in the metadata context. "
        "Parameters of type 'output' are the paths where results will be written. Parameters of type "
        "'volume' require in-memory arrays and cannot be supplied by a plan; if a step needs one, do "
        "not emit the plan - explain what adapter is missing.\n"
        "3. Do not invent parameters that are not declared for the tool.\n"
        "4. If the request can be satisfied with the available auto tools, answer with exactly one "
        "JSON object and nothing else:\n"
        "   {\"type\": \"tool_plan\", \"summary\": \"short plan description\", \"steps\": "
        "[{\"tool\": \"tool_name\", \"arguments\": {...}, \"reason\": \"why this step\"}]}\n"
        "5. If it cannot be done with the available auto tools (needs a human/interactive step, an "
        "unavailable tool, new code, or more information), answer with exactly one JSON object and "
        "nothing else:\n"
        "   {\"type\": \"message\", \"content\": \"explanation of what is missing or what to ask\"}\n"
        "6. Keep steps minimal and sequential. Never return more than "
        + str(MAX_PLAN_STEPS)
        + " steps."
    )

    context_text = build_context_text(context)
    tools_text = build_tools_text(tools)

    user = prompt
    if working_directory:
        user += f"\n\nWorking directory: {working_directory}"
    if context_text:
        user += (
            "\n\nWorking directory metadata context (paths and sizes only; do not claim the file "
            "contents were inspected):\n" + context_text
        )
    if tools_text:
        user += "\n\nAvailable tools (JSON):\n" + tools_text

    messages = [{"role": "system", "content": system}]
    if isinstance(history, list):
        for item in history[-10:]:
            if not isinstance(item, dict):
                continue
            role = str(item.get("role", "")).strip()
            content = str(item.get("content", "")).strip()
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": user})
    return messages


def extract_json(text):
    """Parse strict JSON from model output, tolerating fences or prose around it."""
    text = str(text or "").strip()
    if not text:
        raise ValueError("The model returned an empty answer")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    fence = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if fence:
        candidate = fence.group(1).strip()
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass

    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        candidate = text[start : end + 1]
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass
    raise ValueError("The model answer is not valid JSON")


def normalize_plan(payload):
    if not isinstance(payload, dict):
        raise ValueError("The tool plan must be a JSON object")
    kind = str(payload.get("type", "")).strip()
    if kind == "message":
        content = str(payload.get("content", "")).strip()
        if not content:
            raise ValueError("The message type has no content")
        return {"type": "message", "content": content}

    if kind == "tool_plan":
        steps = payload.get("steps")
        if not isinstance(steps, list) or not steps:
            raise ValueError("The tool plan has no steps")
        if len(steps) > MAX_PLAN_STEPS:
            raise ValueError(f"The tool plan has more than {MAX_PLAN_STEPS} steps")
        normalized = []
        for step in steps:
            if not isinstance(step, dict):
                raise ValueError("Each plan step must be a JSON object")
            tool = str(step.get("tool", "")).strip()
            arguments = step.get("arguments")
            if not tool:
                raise ValueError("A plan step has no tool name")
            if arguments is None:
                arguments = {}
            if not isinstance(arguments, dict):
                raise ValueError(f"Arguments of step '{tool}' must be a JSON object")
            normalized.append(
                {
                    "tool": tool,
                    "arguments": {str(key): value for key, value in arguments.items()},
                    "reason": str(step.get("reason", "") or "").strip(),
                }
            )
        return {
            "type": "tool_plan",
            "summary": str(payload.get("summary", "") or "").strip(),
            "steps": normalized,
        }

    raise ValueError(f"Unknown plan type: {kind or '<empty>'}")


def process_agent(request):
    messages = build_agent_messages(request)
    content, resolved_model = post_chat(messages)
    payload = extract_json(content)
    result = normalize_plan(payload)
    result["ok"] = True
    result["model"] = resolved_model
    return result


def process_chat(request):
    query = str(request.get("query", "")).strip()
    if not query:
        raise ValueError("The query is empty")

    error_context = str(request.get("error_context", "")).strip()
    context = request.get("context")
    user_content = query
    if context:
        context_text = build_context_text(context)
        user_content = (
            f"{user_content}\n\nWorking directory metadata context:\n{context_text}\n\n"
            "Use only these paths when discussing available files. Do not claim that file contents were inspected."
        )
    if error_context:
        user_content = f"{user_content}\n\nError context:\n{error_context}"

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
    if mode == "agent":
        return process_agent(request)
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
