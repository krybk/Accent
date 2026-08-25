# Accent

An Android remote for server-side AI infrastructure. The app stores server
profiles, deploys a container stack onto a chosen server, and talks to it from a
chat: text, images, files, video, voice.

This repository doubles as the **template for the app pipeline**. Future apps
fork it, drop the application half, and keep the scaffolding.

## What carries over to a new app, and what does not

| Directory | Role |
| --- | --- |
| `.github/workflows/` | pipeline, carries over wholesale |
| `scripts/` | pipeline, carries over wholesale |
| `.claude/` | pipeline, carries over (entries cleared) |
| `app/` | application, rewritten |
| `gateway/` | application, rewritten |

## Stack

- **App**: Tauri v2, Rust core, React + TypeScript UI. Android is built in CI
  only — the server has neither Java nor the Android SDK.
- **Gateway**: Rust (axum) in Docker, alongside LiteLLM, Postgres and Caddy.
- **SSH**: `russh` in the app core. The root password is entered once during
  bootstrap and is never stored on the device.

## Commands

- `npm test` — frontend tests
- `npm run typecheck` — type check
- `./scripts/check-secrets.sh` — secrets in the index (runs in CI)
- `node scripts/cache-canary.js [model]` — is prompt caching actually working

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
the environment and failed every cheap-tier call with `400 not a valid model ID`,
pushing that work onto more expensive tiers.

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

**Tiers by task.** Sonnet is the default for the whole automated loop. Opus is
for a human writing `@claude`. Everything the workflows write themselves carries
the `<!-- automated-request -->` marker, which `claude.yml` uses to keep such
requests on Sonnet — otherwise the loop would escalate itself to Opus, since the
only way to wake it is to mention `@claude`.

## Memory between sessions

Two files with distinct roles — do not merge them:

- `.claude/journal.md` — the **historical record**: what was measured, what was
  decided and why, including hypotheses that were disproved. Read it before
  working on cost, models or infrastructure: it holds numbers that are not in the
  code, and reasons that otherwise look arbitrary. Learn something non-obvious,
  add an entry in the same PR.
- `.claude/known-failures.md` — **diagnosed causes of failures** in CI and
  builds. Read it **before** investigating the repository when fixing a red run.
  An entry marked "do not revisit" means the fix was already tried and does not
  work.

A rule for both: only what cannot be derived from the code belongs here. Project
layout, git history and config contents are not duplicated.

## Language

Code, comments, documentation, commit messages and CLI output are in English.
