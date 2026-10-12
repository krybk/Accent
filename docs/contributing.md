# Working on Accent

An Android remote for server-side AI infrastructure. The app stores server
profiles, deploys a container stack onto a chosen server, and talks to it from a
chat: text, images, files, video, voice.

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
- `node scripts/cache-canary.js [model]` — is prompt caching actually working

The canary stays in Node because it talks to an HTTP API and has no reason to
pull the Dart toolchain into a check that must run before anything is built.

## The repository is public

No secret enters history. The gateway token, TLS certificates, provider keys and
the APK signing keystore are generated on the target machine or live in GitHub
Secrets. The repository holds `*.example` files only.

`scripts/check-secrets.sh` is the last net, not the first line: it catches known
key formats and forbidden filenames. When a new place appears where a secret
could take root, update `.gitignore` and that script together.

## Models and money

Model access is direct, with no intermediary. No workflow calls a model any
more; the gateway on a user's server calls the Anthropic API with that server's
own `ANTHROPIC_API_KEY`. OpenRouter was removed on 2026-09-25. What follows is
not general advice but measurements taken on this project. They change which
tier you pick, which is why they live here rather than in someone's memory.

**Exact model IDs, never aliases.** An alias will one day silently move to a
pricier model, and a version change should be a visible commit. The gateway's
IDs are `claude-sonnet-5-5` (Sonnet 5.5) and `claude-opus-5-5`, listed once in
`gateway/lib/src/catalog.dart`; Haiku is retired. There is **no**
`claude-haiku-5` — it was set in the environment once and failed every
cheap-tier call with `400 not a valid model ID`, pushing that work onto more
expensive tiers.

**No provider pinning any more.** Through OpenRouter, Anthropic models were
served by up to nine endpoints and requests had to be pinned to Anthropic or the
prefix cache did not survive the move between providers. A direct connection has
one provider, so there is nothing to pin. The measurement stays in the
[journal](engineering-journal.md).

**Haiku was not always cheaper**, which is part of why it is gone. The minimum
cacheable prefix, measured empirically: Sonnet 5 caches from ~1024 tokens,
Haiku 4.5 only from ~4096. Below the threshold the cache is silently never
created, and Haiku's $1.00/1M input then costs more than Sonnet's $0.20/1M
cached input. The gateway's Sonnet 5.5 tier carries the Sonnet 5 threshold
until the canary is re-run against it.

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

The release workflow needs these set in repository settings. Without them it is
inert rather than broken — it runs and refuses, which is the intended direction
of failure.

| Secret | Used by | Purpose |
| --- | --- | --- |
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
