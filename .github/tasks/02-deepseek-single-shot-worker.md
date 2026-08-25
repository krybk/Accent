# Add a single-shot DeepSeek worker workflow

<!-- parent: krybk/aimanager#1 -->

Commissioned from `krybk/aimanager#1`. It asks for one capability: a workflow that
lets a second, much cheaper model do bounded mechanical work on request, so that a
config edit, a workflow tweak, a documentation pass or tests against an existing
module stop costing a full Sonnet session.

Scope is one workflow, one helper module and its tests. **No application code** —
nothing under `app/`, `gateway/` or `protocol/` is touched by this task.

## What is already decided, and why

Do not reopen these. They were decided upstream or follow from failures this
repository has already paid for.

**Single-shot, not agentic.** One API call, no tool loop. `claude-code-action` is a
harness for the Anthropic Messages protocol; DeepSeek speaks an OpenAI-compatible
one, and tool-calling fidelity through a translation layer fails *quietly*, which
is the worst way for it to fail. So the shape is: read the named files, send them
with the instruction, receive their new contents, write them back. `POST
https://api.deepseek.com/chat/completions`, model `deepseek-chat` (exact ID, never
a `-latest` alias), keyed by `secrets.DEEPSEEK_API_KEY`. `temperature: 0`,
`stream: false`, `max_tokens: 8192`. No `tools` and no `functions` in the payload —
if the model tries to call a tool, this design has been misunderstood.

**The trigger is `issue_comment` containing `@deepseek`, gated on the same author
allowlist `claude.yml` uses.** Copy that gate's *shape*, not just its intent:
bodies and logins arrive through `env:` and are quoted, never interpolated with
`${{ }}` into a `run:` block, because a comment body is attacker-controlled text in
a public repository; the empty-author case is an explicit early return, because
`[[ " " != *" "* ]]` is false and the gate would otherwise fail open; and the
author check comes **before** the phrase check, so a stranger's comment costs
nothing at all.

**The workflow must not be able to trigger itself.** Its own comments are posted
with `AUTOMATION_TOKEN`, so their author is a login on the allowlist — a comment it
writes that contained the trigger phrase would wake it again, forever. Two
independent guards, both cheap: nothing the workflow posts ever contains the
literal trigger phrase, and the job skips any comment body containing its own
marker `<!-- deepseek-worker -->`, which every comment it posts carries.

**Issue comments only.** `issue_comment` also fires on pull request comments, and
"apply this to the PR I am looking at" is a different feature with a different
blast radius (a head branch that may be a fork). If `github.event.issue.pull_request`
is present, post one line saying the worker only takes requests on Issues, and
stop. Every run branches from the default branch and targets it.

**Its pull requests must not auto-merge.** Branch prefix `deepseek/`, not `auto/`.
This is the whole mechanism: the label job in `claude.yml` labels `auto-fixed` only
for branches under `auto/`, and `handle-ci-result` in `auto-fix-loop.yml` merges
only what carries `auto-fixed`. So a `deepseek/` branch cannot reach the merge path
even when CI is green. Label the pull request `ready-to-review` and nothing else —
**never** `auto-fixed` — and say in the body which model wrote it. It stays this way
until there is a reason to trust a second model's unreviewed output that we have
measured rather than assumed.

**Absent key means a clear skip, not a crash.** If `DEEPSEEK_API_KEY` or
`AUTOMATION_TOKEN` is unset, comment on the Issue naming the missing secret, emit a
`::notice::`, and end the job green. A workflow that dies with `Parameter required`
or `Parameter token or opts.auth is required` teaches nobody anything — that exact
failure cost a session already. Nothing watches this workflow's conclusion
(`auto-fix-loop.yml` subscribes to `CI` only), so the comment is the channel, and a
red run here would notify no one.

**Never a partial application.** Parse the entire response and validate it fully
*before* the first byte is written. A patch that half-applied is worse than one
that did not apply: it leaves the branch in a state nobody wrote deliberately, and
the gates then fail for reasons unrelated to the request.

**The parser is a Python module with its own tests, not inline shell.** Fenced-block
parsing in `awk`/`sed` is exactly where a half-written file comes from, and this is
the one part of the workflow whose failure modes must be verifiable without
spending an API call. Python 3 is on the runner image; `unittest` needs no
dependency. It must **not** be JavaScript in a `github-script` block: `github-script`
loads files with `require()`, and adding a root `package.json` (or one arriving
later) makes every `.js` in the repository an ES module and breaks it — a diagnosed
failure, see `docs/known-failures.md`. The module takes a response file and the
requested paths, touches no network and reads no environment, so it is testable.

## The request contract

The comment that wakes the worker:

```
@deepseek <instruction, one or more lines>

files:
- path/to/one
- path/to/two
```

Parsing rules, all enforced:

- The instruction is the text between the trigger phrase and the `files:` line.
  Empty instruction is a refusal.
- `files:` is a line matching `^\s*files:\s*$`. Each path is a following line
  matching `^\s*[-*]\s+(\S+)\s*$`, with surrounding backticks stripped from the
  captured path; the block ends at the first line matching neither. No `files:`
  block is a refusal that shows the expected format.
- At most **5** paths and **200 KB** of total input. Beyond that a single shot is
  no longer bounded work, and truncation is the failure mode that follows.
- Every path must exist in the checkout, be a regular file (not a symlink), be
  inside the repository, and resolve to itself after normalisation — `..`, an
  absolute path, or anything that escapes the worktree is a refusal.
- Refused outright, whatever the request says: `.github/workflows/**` (a second
  model does not edit the trigger wiring that governs it), `scripts/check-secrets.sh`,
  `.gitignore`.

Any refusal is one comment naming precisely what was wrong, and no branch.

## The response contract

The system prompt states this and the workflow enforces it. Two facts drive the
shape: the response is machine-parsed, and markdown files legitimately contain
triple-backtick fences.

- For each file, a header line containing only the path, then a fenced block whose
  fence is **four** backticks (an optional language tag is allowed), then the
  complete new contents, then a closing four-backtick line.
- The set of paths in the response must equal the requested set exactly — no
  extras, no omissions, no duplicates.
- A four-backtick line inside content is a parse failure, not a guess.
- An unterminated fence, an empty block, or any text the parser cannot attribute is
  a parse failure.
- `choices[0].finish_reason` must be `stop`. `length` means truncation, and a
  truncated file that parses is the exact silent corruption this contract exists to
  prevent. Non-2xx, an empty body, or unparseable JSON are the same class.

Every failure here is one comment on the Issue quoting what could not be parsed
(bounded — a few lines, not the whole response), and no branch, no pull request.

## Gates before the pull request

Run only what is relevant to the paths the patch touched; running everything on
every request spends minutes for nothing.

| Touched | Commands |
| --- | --- |
| always | `./scripts/check-secrets.sh` |
| `scripts/*.sh` | `shellcheck scripts/*.sh` |
| `protocol/`, `gateway/` | in each: `dart pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze --fatal-infos`, `dart test` |
| `app/` | `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test` |
| `app/android/**`, `app/pubspec.yaml` | additionally `flutter build apk --debug` |
| `gateway/docker-compose.yml`, `gateway/Dockerfile` | `cp gateway/.env.example gateway/.env && docker compose -f gateway/docker-compose.yml --env-file gateway/.env config >/dev/null` |
| `scripts/deepseek_apply.py` | `python3 scripts/deepseek_apply_test.py` |

A patch that fails a gate is reported in the Issue — the failing command and the
last ~40 lines of its output — and **not pushed**. The pull request never
auto-merges, so these gates are not the safety net; they exist so the worker does
not open a pull request that is already known to be red.

## What to build

Four files, in this order, pushing after each.

1. **`scripts/deepseek_apply.py`** — stdlib only. A `parse(text, requested)`
   returning `{path: contents}` or raising a `ParseError` whose message is a
   sentence a human can act on, a path validator, and a `main()` that writes only
   after everything validated. Nothing about HTTP, secrets or GitHub lives here.
2. **`scripts/deepseek_apply_test.py`** — `unittest`, run with `python3
   scripts/deepseek_apply_test.py`.
3. **`.github/workflows/deepseek.yml`** — the trigger, the gates above, the API
   call, the branch, the pull request and the comments. `concurrency: group:
   deepseek-${{ github.event.issue.number }}`, `cancel-in-progress: false`, so two
   requests on one Issue queue instead of racing on one branch. Branch name
   `deepseek/<issue-number>-<run-number>`; base is the default branch. The pull
   request is opened with `AUTOMATION_TOKEN` so CI actually starts on it, and its
   body names `deepseek-chat` as the author of the patch, links the requesting
   comment, and references the Issue as `Fixes #<n>`.

   That reference is deliberate: `close-issue-on-merge` in `auto-fix-loop.yml`
   parses the first `#<n>` out of a merged pull request body, closes it, and
   reports upstream if that Issue carries a `<!-- parent: -->` marker. A human is
   the one merging here, so a merge closing the requesting Issue is the intended
   chain rather than an accident.

   At most one comment per run, at the end: the pull request link on success, or
   the reason on any refusal or failure. Every comment carries
   `<!-- deepseek-worker -->` and never the trigger phrase.
4. **`ci.yml`, one added step**, inside the existing `secrets` job (which already
   hosts `shellcheck` for the same reason — another job means another runner
   started for a second of work): `python3 scripts/deepseek_apply_test.py`. No new
   job, no change to any existing gate.

Then **`docs/contributing.md`**: the `@deepseek` request format under *Commands*,
and a `DEEPSEEK_API_KEY` row in the *Repository secrets* table.

## What must not change

- `claude.yml`, `tasks.yml`, `auto-fix-loop.yml` — untouched. In particular do not
  add `deepseek/` to `AUTOMATED_PREFIX`, and do not have the new workflow apply
  `auto-fixed`. Either one silently hands unreviewed second-model output to the
  merge path, which is the single thing this design is arranged to prevent.
- `ci.yml` — the one step above and nothing else.
- `scripts/check-secrets.sh` and `.gitignore` — untouched. They are the guarded
  paths in `auto-fix-loop.yml`: a pull request touching either is held for a human,
  so an edit here stalls this task's own merge. (It is known that
  `check-secrets.sh` has no pattern for a DeepSeek key. That gap is a separate
  task, deliberately not this one.)
- No new dependencies: no root `package.json`, no `pip install`, no action that is
  not already used in this repository. Python stdlib only.
- No application code, no new dart or dart test dependency, no change to
  `app/pubspec.yaml`.
- Secrets reach the job only through `env:` from `secrets.*`. Never echoed, never
  written to a file, never included in a comment body, never passed on a command
  line where it would appear in `ps` or a log.
- The apply step writes only to paths the request named, and only inside the
  worktree.
- The DeepSeek request payload is built with `jq -n --arg` (or Python `json.dumps`),
  never by string interpolation. A backtick or a quote in an Issue comment must not
  be able to produce an invalid request, let alone a shell command.

## Acceptance

```
python3 scripts/deepseek_apply_test.py -v
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deepseek.yml'))"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
shellcheck scripts/*.sh
./scripts/check-secrets.sh
```

The tests must cover the failure modes, not the happy path alone. Each one asserts
that on failure **no target file on disk changed** (work in a temporary directory):

- two files, headers and four-backtick fences, parsed to exact contents including a
  trailing newline;
- a path in the response that was not requested;
- a requested path missing from the response;
- two blocks for the same path;
- an unterminated fence;
- content that itself contains triple-backtick fences — parsed intact, which is why
  the fence is four backticks;
- content containing a four-backtick line — a parse failure, never a silent
  truncation;
- an empty block;
- `..`, an absolute path, a symlink, and each refused path (`.github/workflows/x.yml`,
  `scripts/check-secrets.sh`, `.gitignore`) rejected before any write;
- more than 5 paths, and input over 200 KB, both refused.

What cannot be tested before merge: the trigger itself. For `issue_comment`, GitHub
runs the workflow from the **default branch**, so a `deepseek/` or `auto/` branch
cannot exercise it — say so in the pull request body, so whoever merges knows the
first live `@deepseek` comment is the real test, and that a missing
`DEEPSEEK_API_KEY` will show up as a comment rather than a red run.

Push the branch as soon as `scripts/deepseek_apply.py` parses its own tests, before
the workflow exists. Then keep pushing. Finish with `gh pr create --base main` — a
branch with no pull request is work nobody collects.
