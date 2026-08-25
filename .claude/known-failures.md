# Known failures

Diagnosed causes of CI and build failures. Read this **before** investigating the
repository when fixing a red run — the cause is probably already here.

Entry format: symptom, cause, fix. If a fix was tried and did not work, say so
and mark it "do not revisit". Those entries are worth more than the successful
ones: they save a run, and a run costs money.

---

## `400 ... is not a valid model ID`

**Symptom.** Any model call fails with this code, most often on housekeeping
operations (background summaries, subtasks, page fetches) rather than on the main
answer.

**Cause.** A non-existent model ID in the environment or in a workflow. We hit
this with `anthropic/claude-haiku-5` — no such family exists on OpenRouter.

**Fix.** Check the ID against the live list: `curl -s
https://openrouter.ai/api/v1/models | jq -r '.data[].id' | grep anthropic`.
Current: `anthropic/claude-opus-5`, `anthropic/claude-sonnet-5`,
`anthropic/claude-haiku-4.5`.

**Do not revisit:** aliases of the form `~anthropic/claude-haiku-latest`. They
are valid, but they silently move to a different model, which makes a price
increase invisible.

## The cache canary fails with "Cache NOT created"

**Symptom.** `node scripts/cache-canary.js` reports that request 1 wrote zero
tokens to cache.

**Cause.** The prefix is shorter than the minimum cacheable size for that model.
The threshold is tier-dependent and differs by a factor of four: ~1024 tokens on
Sonnet and Opus, ~4096 on Haiku 4.5. Below it the cache is silently not created.

**Fix.** Either extend the stable part of the prefix past the threshold, or accept
that a short task will not cache — and in that case treat Haiku as expensive
rather than cheap (details in `.claude/journal.md`).

**Do not revisit:** the hypothesis that Haiku's threshold is 2048. Checked; at
2452 tokens the cache is still not created.

## The cache canary fails with "Cache created but NOT read"

**Symptom.** Request 1 writes to cache, request 2 reads zero.

**Cause.** Either the prefix changed between requests (a date, an id, a counter
inside the cached part), or the requests went to different providers. The latter
is not rare even for Anthropic models: OpenRouter serves them from up to nine
distinct endpoints.

**Fix.** Move the variable part out of the prefix — it belongs **after**
`cache_control`. And pin the provider in the request body:
`"provider": {"order": ["Anthropic"], "allow_fallbacks": false}`.

## The gateway image fails to build with a dependency downgrade

**Symptom.** `docker build` reports `pub get` downgrading packages
(`< analyzer 12.1.0 (was 14.1.0)`), or the AOT compile fails on paths that do
not exist in the container.

**Cause.** The host's `.dart_tool/` reached the build context and overwrote the
`package_config.json` the container resolved for itself. The paths inside it
point at the host filesystem, so the failure presents as a dependency problem
rather than a copy problem. A floating base image (`dart:stable`) causes the same
symptom for a different reason: the lockfile was resolved by one SDK and is being
re-resolved by another.

**Fix.** Keep `.dart_tool/` out of the context via `.dockerignore`, pin the SDK
image to a specific minor version, and do not run a second `pub get` after
copying source — the resolution from the manifest layer is meant to survive.

**Do not revisit:** adding `dart pub get --offline` after the source copy. That
was the original shape and it is what produced the downgrade; the offline flag
hides the real problem instead of fixing it.

## `dart compile exe` fails with `Cannot open file, path = '/out/...'`

**Symptom.** AOT compilation fails immediately, complaining it cannot open the
output path.

**Cause.** `dart compile exe` does not create the output directory.

**Fix.** `mkdir -p /out` in the same `RUN` layer.

## `./scripts/check-secrets.sh` fails CI

**Symptom.** The run fails on the secrets step.

**Cause.** A key in a known format, or a file from the forbidden list (`.env`,
`*.pem`, `*.jks`, a private SSH key), reached the index.

**Fix.** Remove the file from the index (`git rm --cached`) and add the path to
`.gitignore`. If the secret already reached a published commit, deleting the file
is not enough: **the key must be revoked and reissued**, because the history is
public.
