# Working on Accent

An Android remote for server-side AI infrastructure. The app stores server
profiles, deploys a container stack onto a chosen server, and talks to it from a
chat: text, images, files, video, voice.

This repository doubles as the template for the app pipeline. Future apps fork
it, drop the application half, and keep the scaffolding.

## What carries over to a new app, and what does not

| Directory | Role |
| --- | --- |
| `.github/workflows/` | pipeline, carries over wholesale |
| `scripts/` | pipeline, carries over wholesale |
| `docs/` | pipeline, carries over (entries cleared) |
| `app/` | application, rewritten |
| `gateway/` | application, rewritten |
| `protocol/` | application, rewritten |

## Stack

Dart on both sides. One language, one toolchain, and the chat protocol types are
literally shared code rather than two definitions kept in sync by hand.

- **App**: Flutter. Android is built in CI only — the development server has
  neither Java nor the Android SDK.
- **Gateway**: Dart (`shelf`), AOT-compiled into a container, alongside LiteLLM,
  Postgres and Caddy.
- **Shared**: `protocol/`, used by both, so a change to a request or response
  shape breaks compilation instead of production.
- **SSH**: `dartssh2` in the app. The root password is entered once during
  bootstrap and is never stored on the device.

Two notes on `dartssh2`, both verified rather than assumed (see
[the journal](engineering-journal.md)): it reads keys but cannot generate them —
build the key with `pinenacl` and hand `OpenSSHEd25519KeyPair` the raw bytes,
private half in the 64-byte seed‖public form. And an `authorized_keys` line needs
SSH wire format, not the bare 32 bytes; get it wrong and sshd ignores the line
silently.

The gateway is deliberately not Rust. It is I/O-bound — proxying streams, running
Docker commands, moving files — so Rust would buy nothing measurable and cost a
second language plus a hand-maintained copy of every protocol type. Anything
genuinely CPU-heavy (speech-to-text) runs in its own container.

## Commands

- `dart analyze --fatal-infos` — in each of `protocol/`, `gateway/`, `app/`
- `dart format --output=none --set-exit-if-changed protocol gateway app`
- `dart test` in `protocol/` and `gateway/`; `flutter test` in `app/`
- `./scripts/check-secrets.sh` — secrets in the index (runs in CI)
- `python3 scripts/deepseek_apply_test.py` — the DeepSeek worker's parser (runs
  in CI)
- `node scripts/cache-canary.js [model]` — is prompt caching actually working

The canary stays in Node because it talks to an HTTP API and has no reason to
pull the Dart toolchain into a check that must run before anything is built.

### Asking DeepSeek for a small change

`deepseek.yml` puts a second, much cheaper model behind a comment on an Issue, so
a config edit, a documentation pass or tests against a module that already exists
stop costing a full Sonnet session. Comment on an Issue — not on a pull request,
which it refuses — from a login on its allowlist:

```
@deepseek Rename the field to `serverId`, keeping the JSON key unchanged.

files:
- protocol/lib/src/server.dart
- gateway/lib/src/handler.dart
```

The instruction is everything between the trigger phrase and the `files:` line,
and each path is a list item under it. What is worth knowing before using it:

- It is **one API call** to `deepseek-chat`, not an agent. It reads the files you
  named, asks for their complete new contents, and writes them back. It cannot
  explore the repository, run a command, or decide that a different file is the
  one that needs changing.
- At most **5 files** and **200 KB** of input. `.github/workflows/**`,
  `scripts/check-secrets.sh` and `.gitignore` are refused whatever the request
  says, as is any path that is a symlink or reaches outside the worktree.
- Either the whole answer applies or none of it does. Anything the parser cannot
  attribute — a missing file, a duplicate block, an unclosed fence, a truncated
  answer — is a refusal with no branch. A half-applied patch is worse than none.
- The relevant gates run before the push, so it does not open a pull request
  already known to be red.
- The branch is under `deepseek/`, which is what keeps it away from auto-merge:
  only `auto/` branches get labelled `auto-fixed`, and only that label merges. Its
  pull requests are labelled `ready-to-review` and wait for a human.
- Every outcome is one comment on the Issue. A missing `DEEPSEEK_API_KEY` is
  reported there rather than as a red run — nothing subscribes to this workflow's
  conclusion, so a failed run would notify nobody.

## The repository is public

No secret enters history. The gateway token, TLS certificates, provider keys and
the APK signing keystore are generated on the target machine or live in GitHub
Secrets. The repository holds `*.example` files only.

`scripts/check-secrets.sh` is the last net, not the first line: it catches known
key formats and forbidden filenames. When a new place appears where a secret
could take root, update `.gitignore` and that script together.

## Models and money

Model access goes through OpenRouter (`ANTHROPIC_BASE_URL`). What follows is not
general advice but measurements taken on this project. They change which tier you
pick, which is why they live here rather than in someone's memory.

**Exact model IDs, never aliases.** `~anthropic/claude-opus-latest` will one day
silently move to a pricier model, and a version change should be a visible
commit. Current IDs: `anthropic/claude-opus-5`, `anthropic/claude-sonnet-5`,
`anthropic/claude-haiku-4.5`. There is **no** `claude-haiku-5` — it was set in
the environment once and failed every cheap-tier call with `400 not a valid model
ID`, pushing that work onto more expensive tiers.

**Pin the provider.** Anthropic models on OpenRouter are not served by one
provider: `haiku-4.5` has eight endpoints, `sonnet-5` has nine (Anthropic,
Google, Azure, Bedrock). Without pinning, adjacent requests land on different
providers and the prefix cache does not survive the move. On every request:

```json
"provider": { "order": ["Anthropic"], "allow_fallbacks": false }
```

**Haiku is not always cheaper.** The minimum cacheable prefix, measured
empirically: Sonnet 5 caches from ~1024 tokens, Haiku 4.5 only from ~4096. Below
the threshold the cache is silently never created, and Haiku's $1.00/1M input
then costs more than Sonnet's $0.20/1M cached input. Use Haiku for mechanical
work behind a long stable prefix, not for short one-off calls.

**The dominant cost is resending history**, not the length of the answer. On
Sonnet a cache write costs $0.0123 against $0.0010 for a read of the same prefix
— a factor of twelve. Therefore a working cache matters more than the choice of
tier, and `cache-canary.js` runs after any change to prompts.

## Releasing Android binaries

A release is a tag. Bump `version:` in `app/pubspec.yaml`, tag `v<version>`, and
push the tag; `release.yml` builds signed APKs and attaches them to a GitHub
release. The tag and the pubspec version must agree — the workflow refuses
otherwise, because publishing a `v0.2.0` tag containing 0.1.0 binaries is a
mistake nobody notices until a user reports the wrong version.

The `+N` build number after the version is what Android uses to decide which
build is newer. It must increase on every published build, even when the
semantic version does not.

Four APKs are published: one per architecture (`arm64-v8a`, `armeabi-v7a`,
`x86_64`) and a universal one. Split builds exist because a universal APK
carries native code for every architecture — measured at 43 MB against 16 MB for
arm64 alone, for no benefit on any single device. `SHA256SUMS.txt` ships
alongside, so a download can be verified without trusting the page it came from.

### Signing, and why it cannot be skipped

Android identifies an app by its signature, and it refuses an upgrade whose
signature changed. Two consequences that are worth stating plainly:

- A release signed with the debug key installs fine, so nobody notices — until
  the first real update, which then cannot be installed over it. Users would have
  to uninstall, losing their server profiles. Both the Gradle config and the
  workflow therefore **fail** rather than fall back to the debug key.
- Losing the keystore means never being able to update the app for anyone who
  already installed it. Back it up somewhere that will still exist in five years.

Create one once (`app/android/key.properties.example` has the command), then put
it in repository secrets as `ANDROID_KEYSTORE_BASE64` (`base64 -w0` of the
`.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

## Repository secrets

The pipeline needs these set in repository settings. Without them the workflows
are inert rather than broken — they run and refuse, which is the intended
direction of failure.

| Secret | Used by | Purpose |
| --- | --- | --- |
| `OPENROUTER_API_KEY` | `claude.yml` | model access |
| `DEEPSEEK_API_KEY` | `deepseek.yml` | the second model's key. Absent, the worker says so in a comment on the Issue and ends green — nothing watches its conclusion, so failing would tell nobody |
| `AUTOMATION_TOKEN` | `claude.yml`, `auto-fix-loop.yml`, `deepseek.yml` | a PAT, so PRs it opens actually start CI. It must belong to a login in `ALLOWED_AUTHORS`, or the retry comment it posts will be refused by the author gate |
| `ANDROID_KEYSTORE_BASE64` | `release.yml` | release signing |
| `ANDROID_KEYSTORE_PASSWORD` | `release.yml` | release signing |
| `ANDROID_KEY_ALIAS` | `release.yml` | release signing |
| `ANDROID_KEY_PASSWORD` | `release.yml` | release signing |

## Project memory

Two files with distinct roles — do not merge them:

- [`engineering-journal.md`](engineering-journal.md) — the **historical record**:
  what was measured, what was decided and why, including hypotheses that were
  disproved. Read it before working on cost, models or infrastructure: it holds
  numbers that are not in the code, and reasons that otherwise look arbitrary.
  Learn something non-obvious, add an entry in the same change.
- [`known-failures.md`](known-failures.md) — **diagnosed causes of failures** in
  CI and builds. Read it **before** investigating the repository when fixing a
  red run. An entry marked "do not revisit" means the fix was already tried and
  does not work.

A rule for both: only what cannot be derived from the code belongs here. Project
layout, git history and config contents are not duplicated.

## Language

Code, comments, documentation, commit messages and CLI output are in English.
