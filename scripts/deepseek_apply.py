#!/usr/bin/env python3
"""Request and response handling for the single-shot DeepSeek worker.

Nothing here talks to the network, reads a secret, or knows anything about
GitHub. The module takes an Issue comment body or a saved API response plus the
paths the request named, and either produces a validated result or refuses with
a sentence a human can act on. That is the whole point: the failure modes of a
fenced-block parser are the ones that produce a half-written file, and they must
be verifiable without spending an API call — see `deepseek_apply_test.py`.

Two rules hold throughout:

- Nothing is written until everything has validated. A patch that half-applied
  leaves the branch in a state nobody wrote deliberately, and the gates then
  fail for reasons unrelated to the request.
- An ambiguity is a failure, never a guess. A four-backtick line inside file
  contents would silently truncate that file, which is precisely the corruption
  this contract exists to prevent.

Subcommands:

  request  --body-file B --payload P --paths-file L [--message-file M]
           Parse the comment, validate the paths, write the API request JSON.
  apply    --response R --paths-file L [--http-status N] [--message-file M]
           Parse the response and write the files, all or nothing.

Exit codes: 0 success, 2 a refusal or a parse failure whose message belongs in
the Issue comment, 1 anything unforeseen.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

# The trigger phrase, defined here so the request parser and the workflow agree
# on one spelling. The workflow's own comments must never contain it.
TRIGGER = "@deepseek"

# Bounds on a single shot. Beyond them this stops being bounded mechanical work,
# and truncation is the failure mode that follows.
MAX_FILES = 5
MAX_INPUT_BYTES = 200 * 1024

# Four backticks, not three: markdown files legitimately contain triple-backtick
# fences, and a documentation pass is one of the things this worker is for.
FENCE = "`" * 4
FENCE_RE = re.compile(r"^\s*`{4,}\s*[A-Za-z0-9_.+-]*\s*$")

FILES_LINE_RE = re.compile(r"^\s*files:\s*$")
LIST_ITEM_RE = re.compile(r"^\s*[-*]\s+(\S+)\s*$")

# Refused whatever the request says. The workflows are the trigger wiring that
# governs this worker, so a second model does not edit them; `check-secrets.sh`
# and `.gitignore` are the guarded paths in `auto-fix-loop.yml`, so a patch
# touching either would stall behind human review anyway.
REFUSED_PREFIXES = (".github/workflows/",)
REFUSED_PATHS = frozenset({"scripts/check-secrets.sh", ".gitignore"})

MODEL = "deepseek-chat"
MAX_TOKENS = 8192

SYSTEM_PROMPT = """\
You are applying a small, bounded edit to files in a git repository. Your answer \
is read by a parser, not by a human, and a malformed answer is discarded whole.

Answer with nothing but the new contents of every file listed below, in this \
format, and in this order:

<path>
{fence}
<the complete new contents of that file>
{fence}

Rules, all enforced by the parser:

- The fence is exactly four backticks. A language tag after the opening fence is \
allowed. Never emit a line of four or more backticks inside file contents; if the \
contents need a fence of their own, three backticks is what markdown uses.
- Emit the complete file, not a diff, not an excerpt, and never an elision such \
as "... unchanged ...".
- Emit exactly one block per requested path, and no block for any other path.
- No prose before, between or after the blocks. No explanation, no summary.
- Preserve the existing style of each file: indentation, quoting, comment \
density, and line width.

The requested paths, exactly these:

{paths}
"""


class WorkerError(Exception):
    """A refusal or a failure whose message is meant for the Issue comment."""


class RequestError(WorkerError):
    """The comment does not express a request this worker can carry out."""


class PathError(WorkerError):
    """A path the request named cannot be touched."""


class ParseError(WorkerError):
    """The response does not satisfy the response contract."""


def _clip(text, limit=160):
    """One line, bounded — error messages go into a comment, not a log."""
    flat = " ".join(str(text).split())
    return flat if len(flat) <= limit else flat[: limit - 1] + "…"


def quote(text, max_lines=6, limit=160):
    """The first few lines of something unparseable, bounded on both axes."""
    lines = str(text).splitlines()
    shown = [_clip(line, limit) for line in lines[:max_lines]]
    if len(lines) > max_lines:
        shown.append("… ({} more lines)".format(len(lines) - max_lines))
    return "\n".join(shown)


# --------------------------------------------------------------------------- #
# The request contract
# --------------------------------------------------------------------------- #


def parse_request(body):
    """Return (instruction, paths) from a comment body, or raise RequestError.

    The instruction is the text between the trigger phrase and the `files:`
    line. Paths are the list items directly under it; the block ends at the
    first line that is not a list item, blank lines included.
    """
    lines = (body or "").splitlines()

    trigger_at = None
    for index, line in enumerate(lines):
        if TRIGGER in line:
            trigger_at = index
            break
    if trigger_at is None:
        raise RequestError(
            "The comment does not contain the trigger phrase, so there is "
            "nothing to do."
        )

    files_at = None
    for index in range(trigger_at, len(lines)):
        if FILES_LINE_RE.match(lines[index]):
            files_at = index
            break
    if files_at is None:
        raise RequestError(
            "The request has no `files:` block, so there is nothing to edit. "
            "The expected shape is a line reading `files:` followed by one list "
            "item per path:\n\n"
            "```\n<trigger> rename the field\n\nfiles:\n- path/to/one\n"
            "- path/to/two\n```"
        )

    head = lines[trigger_at].split(TRIGGER, 1)[1]
    instruction = "\n".join([head] + lines[trigger_at + 1 : files_at]).strip()
    if not instruction:
        raise RequestError(
            "The request has no instruction: everything between the trigger "
            "phrase and the `files:` line is blank, so there is nothing to ask "
            "for."
        )

    paths = []
    for line in lines[files_at + 1 :]:
        match = LIST_ITEM_RE.match(line)
        if not match:
            break
        path = match.group(1).strip("`")
        if path and path not in paths:
            paths.append(path)

    if not paths:
        raise RequestError(
            "The `files:` block lists no paths. Each path is a list item on its "
            "own line, as in `- path/to/one`."
        )

    return instruction, paths


def validate_paths(paths, root=".", instruction=""):
    """Raise PathError unless every path is one this worker may write.

    Every check happens here, before a single byte is read for the request and
    long before one is written back.
    """
    if not paths:
        raise PathError("The request names no paths.")

    if len(paths) > MAX_FILES:
        raise PathError(
            "The request names {} paths; at most {} are accepted, because "
            "beyond that a single shot is no longer bounded work.".format(
                len(paths), MAX_FILES
            )
        )

    root_real = os.path.realpath(root)
    total = len(instruction.encode("utf-8"))

    for path in paths:
        shown = _clip(path, 80)

        if path != path.strip() or not path:
            raise PathError("`{}` is not a usable path.".format(shown))

        if os.path.isabs(path) or path.startswith("/"):
            raise PathError(
                "`{}` is an absolute path. Paths are relative to the repository "
                "root.".format(shown)
            )

        normalised = os.path.normpath(path)
        if ".." in normalised.split(os.sep):
            raise PathError(
                "`{}` climbs out of the repository with `..`.".format(shown)
            )
        if normalised != path:
            raise PathError(
                "`{}` does not resolve to itself after normalisation (`{}`). "
                "Write the plain path.".format(shown, _clip(normalised, 80))
            )

        if normalised in REFUSED_PATHS or normalised.startswith(REFUSED_PREFIXES):
            raise PathError(
                "`{}` is refused whatever the request says: the workflows are "
                "the trigger wiring that governs this worker, and "
                "`scripts/check-secrets.sh` and `.gitignore` are held for human "
                "review anyway.".format(shown)
            )

        full = os.path.join(root_real, normalised)

        if os.path.islink(full):
            raise PathError(
                "`{}` is a symlink, and this worker rewrites regular files "
                "only.".format(shown)
            )
        if not os.path.exists(full):
            raise PathError("`{}` does not exist in the checkout.".format(shown))
        if not os.path.isfile(full):
            raise PathError("`{}` is not a regular file.".format(shown))
        if os.path.realpath(full) != full:
            raise PathError(
                "`{}` reaches outside the worktree through a symlinked "
                "directory.".format(shown)
            )

        total += os.path.getsize(full)

    if total > MAX_INPUT_BYTES:
        raise PathError(
            "The request is {} bytes of input; the ceiling is {} bytes, because "
            "past it the answer gets truncated rather than "
            "finished.".format(total, MAX_INPUT_BYTES)
        )

    return [os.path.normpath(path) for path in paths]


def read_files(paths, root="."):
    """Current contents of already-validated paths."""
    return {
        path: open(
            os.path.join(root, path), "r", encoding="utf-8", errors="strict"
        ).read()
        for path in paths
    }


def build_payload(instruction, files):
    """The DeepSeek request body, built with json.dumps and never by hand.

    Single-shot: no `tools`, no `functions`. If the model tries to call a tool,
    this design has been misunderstood.
    """
    blocks = [
        "{}\n{}\n{}\n{}".format(path, FENCE, contents.rstrip("\n"), FENCE)
        for path, contents in files.items()
    ]
    user = "{}\n\nThe files as they stand, in the same format your answer must " \
           "use:\n\n{}".format(instruction, "\n\n".join(blocks))
    system = SYSTEM_PROMPT.format(
        fence=FENCE,
        paths="\n".join("- {}".format(path) for path in files),
    )
    return {
        "model": MODEL,
        "temperature": 0,
        "stream": False,
        "max_tokens": MAX_TOKENS,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }


# --------------------------------------------------------------------------- #
# The response contract
# --------------------------------------------------------------------------- #


def is_fence(line):
    return bool(FENCE_RE.match(line))


def extract_message(raw, http_status=None):
    """The assistant text out of an API response, or raise ParseError.

    A non-2xx status, an empty body, unparseable JSON and a `finish_reason` that
    is not `stop` are one class of failure: the answer cannot be trusted to be
    complete, and a truncated file that parses is exactly the silent corruption
    this contract prevents.
    """
    if http_status is not None:
        try:
            status = int(http_status)
        except (TypeError, ValueError):
            status = 0
        if not 200 <= status < 300:
            raise ParseError(
                "The API answered HTTP {}. The body began:\n\n{}".format(
                    http_status, quote(raw)
                )
            )

    if not (raw or "").strip():
        raise ParseError("The API returned an empty body.")

    try:
        payload = json.loads(raw)
    except ValueError as error:
        raise ParseError(
            "The API response is not JSON ({}). It began:\n\n{}".format(
                _clip(error), quote(raw)
            )
        )

    if isinstance(payload, dict) and isinstance(payload.get("error"), dict):
        raise ParseError(
            "The API returned an error: {}".format(
                _clip(payload["error"].get("message") or payload["error"])
            )
        )

    choices = payload.get("choices") if isinstance(payload, dict) else None
    if not isinstance(choices, list) or not choices:
        raise ParseError(
            "The API response carries no `choices`. It began:\n\n{}".format(
                quote(raw)
            )
        )

    choice = choices[0] if isinstance(choices[0], dict) else {}
    reason = choice.get("finish_reason")
    if reason != "stop":
        raise ParseError(
            "`finish_reason` is `{}`, not `stop`. The answer was cut off, and a "
            "truncated file that happens to parse is the corruption this "
            "contract exists to prevent. Nothing was written.".format(
                _clip(reason)
            )
        )

    message = choice.get("message") or {}
    content = message.get("content") if isinstance(message, dict) else None
    if not isinstance(content, str) or not content.strip():
        raise ParseError("The API returned a choice with no message content.")

    return content


def parse(text, requested):
    """Map every requested path to its new contents, or raise ParseError.

    A path header, an opening four-backtick fence, the complete contents, a
    closing four-backtick line. Anything the parser cannot attribute to a
    requested path is a failure, and so is a set of paths that is not exactly
    the requested one.
    """
    requested = list(requested)
    if not requested:
        raise ParseError("No paths were requested, so there is nothing to parse.")
    wanted = set(requested)

    lines = (text or "").splitlines()
    found = {}
    index = 0

    while index < len(lines):
        line = lines[index]
        if not line.strip():
            index += 1
            continue

        if is_fence(line):
            raise ParseError(
                "Line {} opens a fenced block with no path above it. Every "
                "block must be preceded by a line containing only the file "
                "path.".format(index + 1)
            )

        header = line.strip().strip("`").strip()

        after = index + 1
        while after < len(lines) and not lines[after].strip():
            after += 1
        if after >= len(lines) or not is_fence(lines[after]):
            raise ParseError(
                "Line {} cannot be attributed to any file — it is neither a "
                "path followed by a four-backtick fence nor part of a fenced "
                "block:\n\n{}".format(index + 1, quote(line, max_lines=1))
            )

        if header not in wanted:
            raise ParseError(
                "The response contains a block for `{}`, which was not "
                "requested. The request named: {}.".format(
                    _clip(header, 80), ", ".join("`{}`".format(p) for p in requested)
                )
            )
        if header in found:
            raise ParseError(
                "The response contains more than one block for `{}`. One block "
                "per file, and this one is ambiguous.".format(header)
            )

        body = []
        cursor = after + 1
        closed = False
        while cursor < len(lines):
            if is_fence(lines[cursor]):
                closed = True
                break
            body.append(lines[cursor])
            cursor += 1

        if not closed:
            raise ParseError(
                "The block for `{}` opened on line {} is never closed by a "
                "four-backtick line, so its contents are incomplete.".format(
                    header, after + 1
                )
            )
        if not any(entry.strip() for entry in body):
            raise ParseError(
                "The block for `{}` is empty. An empty file is not something "
                "this worker writes by accident.".format(header)
            )

        found[header] = "\n".join(body) + "\n"
        index = cursor + 1

    missing = [path for path in requested if path not in found]
    if missing:
        raise ParseError(
            "The response has no block for {}. Every requested file must come "
            "back in full, so nothing was written.".format(
                ", ".join("`{}`".format(path) for path in missing)
            )
        )

    return found


def write_files(files, root="."):
    """Write validated contents. Called only once everything has validated."""
    for path, contents in files.items():
        target = os.path.join(root, path)
        with open(target, "w", encoding="utf-8", newline="") as handle:
            handle.write(contents)


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #


def _read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def _write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def _command_request(args):
    instruction, paths = parse_request(_read(args.body_file))
    paths = validate_paths(paths, root=args.root, instruction=instruction)
    files = read_files(paths, root=args.root)
    _write(
        args.payload,
        json.dumps(build_payload(instruction, files), ensure_ascii=False) + "\n",
    )
    _write(args.paths_file, "".join(path + "\n" for path in paths))
    print("Requesting {} file(s): {}".format(len(paths), ", ".join(paths)))
    return 0


def _command_apply(args):
    paths = [line.strip() for line in _read(args.paths_file).splitlines()]
    paths = [path for path in paths if path]
    # Validated a second time on purpose: this is the step that writes, and it
    # must not trust a path list it did not check itself.
    paths = validate_paths(paths, root=args.root)
    content = extract_message(_read(args.response), http_status=args.http_status)
    files = parse(content, paths)
    write_files(files, root=args.root)
    print("Applied {} file(s): {}".format(len(files), ", ".join(files)))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repository root")
    subcommands = parser.add_subparsers(dest="command", required=True)

    request = subcommands.add_parser("request", help="comment body -> API request")
    request.add_argument("--body-file", required=True)
    request.add_argument("--payload", required=True)
    request.add_argument("--paths-file", required=True)
    request.add_argument("--message-file")
    request.set_defaults(handler=_command_request)

    apply_ = subcommands.add_parser("apply", help="API response -> files on disk")
    apply_.add_argument("--response", required=True)
    apply_.add_argument("--paths-file", required=True)
    apply_.add_argument("--http-status")
    apply_.add_argument("--message-file")
    apply_.set_defaults(handler=_command_apply)

    args = parser.parse_args(argv)

    try:
        return args.handler(args)
    except WorkerError as error:
        message = str(error)
        if getattr(args, "message_file", None):
            _write(args.message_file, message + "\n")
        sys.stderr.write(message + "\n")
        return 2


if __name__ == "__main__":
    sys.exit(main())
