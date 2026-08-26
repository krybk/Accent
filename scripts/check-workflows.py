#!/usr/bin/env python3
"""Validate workflow files and the JavaScript embedded in them.

An `actions/github-script` step's body is a YAML string. Nothing type-checks it,
nothing lints it, and nothing parses it until the moment it runs in production —
so a typo in one ships green and fails on the event it was written for. That has
happened, and this exists so it cannot happen quietly.

Checks, per workflow:
  * the YAML parses;
  * every job has an `on`-reachable trigger and at least one step;
  * every embedded `script:` is syntactically valid JavaScript (`node --check`);
  * `claude_args` contains no `#` line, because it is a block scalar and such a
    line becomes a command-line argument rather than a comment.
"""

from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile

import yaml

WORKFLOWS = pathlib.Path(".github/workflows")


def embedded_scripts(workflow: dict):
    """Yields (job, step name, script body) for every github-script step."""
    for job_name, job in (workflow.get("jobs") or {}).items():
        for step in job.get("steps") or []:
            body = (step.get("with") or {}).get("script")
            if body:
                yield job_name, step.get("name", step.get("uses", "?")), body


def claude_args(workflow: dict):
    for job_name, job in (workflow.get("jobs") or {}).items():
        for step in job.get("steps") or []:
            args = (step.get("with") or {}).get("claude_args")
            if args:
                yield job_name, step.get("name", "?"), args


def check(path: pathlib.Path) -> list[str]:
    problems: list[str] = []
    try:
        doc = yaml.safe_load(path.read_text())
    except yaml.YAMLError as error:
        return [f"{path}: YAML does not parse: {error}"]

    if not isinstance(doc, dict):
        return [f"{path}: not a mapping"]

    # YAML 1.1 reads a bare `on` as the boolean True, which is why this looks
    # for both. GitHub accepts the file either way; only our reader needs care.
    if "on" not in doc and True not in doc:
        problems.append(f"{path}: no trigger — this workflow can never run")

    jobs = doc.get("jobs") or {}
    if not jobs:
        problems.append(f"{path}: no jobs")
    for name, job in jobs.items():
        if not (job.get("steps") or job.get("uses")):
            problems.append(f"{path}: job '{name}' has neither steps nor uses")

    for job_name, step_name, body in embedded_scripts(doc):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".cjs", delete=False
        ) as handle:
            # The body is a function body referencing globals the action
            # injects, so it is wrapped before checking. `node --check` only
            # parses; nothing here is executed.
            handle.write(
                "const github={},context={},core={},io={},glob={},exec={};\n"
                "function require(){return {}}\n"
                "async function __wrapped(){\n" + body + "\n}\n"
            )
            temp = handle.name
        result = subprocess.run(
            ["node", "--check", temp], capture_output=True, text=True
        )
        pathlib.Path(temp).unlink()
        if result.returncode != 0:
            detail = (result.stderr or "").strip().splitlines()
            first = detail[0] if detail else "unknown syntax error"
            problems.append(
                f"{path}: {job_name}/{step_name}: script does not parse: {first}"
            )

    for job_name, step_name, args in claude_args(doc):
        for line in args.splitlines():
            if line.strip().startswith("#"):
                problems.append(
                    f"{path}: {job_name}/{step_name}: claude_args is a block "
                    f"scalar, so this line becomes an argument: {line.strip()!r}"
                )

    return problems


def main() -> int:
    if not WORKFLOWS.is_dir():
        print(f"{WORKFLOWS} does not exist", file=sys.stderr)
        return 1

    files = sorted(
        p for p in WORKFLOWS.iterdir() if p.suffix in {".yml", ".yaml"}
    )
    if not files:
        print(f"no workflows in {WORKFLOWS}", file=sys.stderr)
        return 1

    problems: list[str] = []
    for path in files:
        found = check(path)
        print(f"{'FAIL' if found else 'ok  '}  {path}")
        problems.extend(found)

    if problems:
        print(f"\n{len(problems)} problem(s):", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    print(f"\n{len(files)} workflow(s) valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
