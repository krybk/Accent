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

## `./scripts/check-secrets.sh` fails CI

**Symptom.** The run fails on the secrets step.

**Cause.** A key in a known format, or a file from the forbidden list (`.env`,
`*.pem`, `*.jks`, a private SSH key), reached the index.

**Fix.** Remove the file from the index (`git rm --cached`) and add the path to
`.gitignore`. If the secret already reached a published commit, deleting the file
is not enough: **the key must be revoked and reissued**, because the history is
public.
