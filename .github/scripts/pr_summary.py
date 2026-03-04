"""Generate an AI summary for a pull request and update its description."""

import json
import os
import re
import subprocess
import urllib.request

ANTHROPIC_API_KEY = os.environ["ANTHROPIC_API_KEY"]
PR_NUMBER = os.environ["PR_NUMBER"]
BASE_REF = os.environ["BASE_REF"]

START_MARKER = "<!-- ai-summary-start -->"
END_MARKER = "<!-- ai-summary-end -->"

MAX_DIFF_CHARS = 80_000

PROMPT = (
    "Summarize this pull request diff. Output a concise markdown summary with:\n"
    "- A one-line overall summary\n"
    "- A bullet list of key changes grouped by area\n\n"
    "Keep it short and useful for code reviewers. "
    "Do not include any preamble, just output the summary.\n\n"
    "Diff:\n"
)


def get_diff() -> str:
    result = subprocess.run(
        ["git", "diff", f"origin/{BASE_REF}...HEAD", "--", ".", ":!*.lock", ":!*.sum"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout[:MAX_DIFF_CHARS]


def call_claude(diff: str) -> str:
    payload = json.dumps({
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": PROMPT + diff}],
    }).encode()

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-Api-Key": ANTHROPIC_API_KEY,
            "Anthropic-Version": "2023-06-01",
        },
    )

    with urllib.request.urlopen(req) as resp:
        body = json.loads(resp.read())

    return body["content"][0]["text"]


def get_pr_body() -> str:
    result = subprocess.run(
        ["gh", "pr", "view", PR_NUMBER, "--json", "body", "-q", ".body"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def update_pr_body(new_body: str) -> None:
    subprocess.run(
        ["gh", "pr", "edit", PR_NUMBER, "--body", new_body],
        check=True,
    )


def main() -> None:
    diff = get_diff()
    if not diff.strip():
        print("No diff found, skipping summary.")
        return

    print("Calling Claude API...")
    summary = call_claude(diff)

    ai_section = f"{START_MARKER}\n## Summary (AI-generated)\n{summary}\n{END_MARKER}"

    current_body = get_pr_body()

    pattern = re.compile(
        re.escape(START_MARKER) + r".*?" + re.escape(END_MARKER),
        re.DOTALL,
    )

    if pattern.search(current_body):
        new_body = pattern.sub(ai_section, current_body)
    else:
        new_body = f"{ai_section}\n\n{current_body}" if current_body else ai_section

    update_pr_body(new_body)
    print("PR description updated with AI summary.")


if __name__ == "__main__":
    main()
