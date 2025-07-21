import json
import subprocess
from collections import Counter
import yaml
import os

ROOT = os.path.dirname(os.path.abspath(__file__))


def run_lint() -> list:
    """Run ansible-lint and return JSON results."""
    cmd = ["ansible-lint", "-f", "json"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode not in (0, 2):
        raise SystemExit(proc.stderr)
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []


def summarize(results: list) -> Counter:
    counts = Counter()
    for item in results:
        # ansible-lint JSON uses `check_name` for rule identifier
        rid = item.get("check_name")
        if not rid and "rule" in item:
            rule = item.get("rule", {})
            rid = rule.get("id") or rule.get("name")
        if rid:
            counts[rid] += 1
    return counts


def main() -> None:
    results = run_lint()
    counts = summarize(results)
    total = sum(counts.values())

    summary_md = ["## ansible-lint violation summary"]
    for rid, num in counts.most_common():
        summary_md.append(f"- {rid}: {num}")
    summary_md.append(f"\nTotal violations: {total}")

    with open(os.path.join(ROOT, "lint_status.md"), "w") as fh:
        fh.write("\n".join(summary_md) + "\n")

    with open(os.path.join(ROOT, "lint_status.yaml"), "w") as fh:
        yaml.safe_dump({"violations": dict(counts), "total": total}, fh)

    print("lint_status.md generated")


if __name__ == "__main__":
    main()
