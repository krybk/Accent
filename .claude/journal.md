# Journal: what was found, and why things were decided this way

Memory between sessions. `CLAUDE.md` holds the short rules; this file holds how
those rules were arrived at and what stands behind each decision, so nobody
rediscovers the same thing twice or reverts work over a forgotten reason.

House rules: one entry per question settled. Date, fact, measurement,
conclusion. Do not delete hypotheses of your own that were disproved — they are
worth more than the confirmed ones, because those are exactly what time gets
spent on again.

**The repository is public.** What belongs here is anything reproducible by
anyone: model behaviour, thresholds, prices, how an API is shaped. What does not
belong here is the names and addresses of working servers, account balances, and
anything else describing specific infrastructure — those notes live outside the
repository.

---

## 2026-08-25. A broken cheap tier

The environment had `ANTHROPIC_DEFAULT_HAIKU_MODEL="anthropic/claude-haiku-5"`.
No such model exists on OpenRouter. Every call to the cheap tier — background
summaries, subtasks, housekeeping calls — failed with
`400 ... is not a valid model ID`, and the work went to more expensive tiers.
Found by accident: a page fetch failed mid-session.

Fixed to `anthropic/claude-haiku-4.5`; all three tiers verified with live calls.

**Conclusion about diagnosis:** a broken cheap tier does not show up in the bill
as an error. It shows up as "somehow expensive". Verify that a model ID exists
when changing it, not after the next invoice.

## 2026-08-25. Disproved: "Anthropic on OpenRouter has a single provider"

I claimed that pinning a provider for Anthropic models was pointless — one
provider, so `provider.order` with `allow_fallbacks: false` changes nothing.
**This is wrong.** `GET /api/v1/models/{id}/endpoints` shows eight endpoints for
`anthropic/claude-haiku-4.5` and nine for `anthropic/claude-sonnet-5`: Anthropic,
Google, Azure and Amazon Bedrock in several variants, at differing prices (some
carry roughly a 10% markup).

Measurement: unpinned, two adjacent requests both went to Amazon Bedrock; pinned,
both went to Anthropic. The `provider` field is accepted and honoured on the
`/api/v1/messages` endpoint.

**Conclusion into the rules:** pin the provider on every request. The
requirement as originally stated was right; my objections were not.

## 2026-08-25. Haiku's caching threshold is four times higher

The cache canary showed something odd: a 1844-token prefix caches on Sonnet 5 and
does not cache on Haiku 4.5. The first hypothesis — a 2048 threshold on Haiku
against 1024 on Sonnet — **was not confirmed**: at 2452 tokens the cache still
was not created. The second hypothesis, provider routing, was **also not
confirmed**: pinning Anthropic changed nothing.

Threshold measured by stepping up, provider pinned:

| Prefix | Cache write |
| --- | --- |
| 2447 tokens | 0 |
| 3663 tokens | 0 |
| 4879 tokens | 4866 |

Haiku 4.5's threshold is around **4096** tokens, four times higher than Sonnet
and Opus. Below it the cache is not created silently: no error, no warning.

**Non-obvious consequence:** on a prefix shorter than 4096 tokens, Haiku input
costs $1.00/1M while Sonnet's cached input costs $0.20/1M. On short requests the
"cheap" tier is five times more expensive than Sonnet with a working cache. The
cheap tier is only cheap behind a long, stable prefix.

## 2026-08-25. What caching actually costs

Measured on one and the same prefix (~4870 tokens), cost taken from
`/api/v1/generation` rather than computed from a price list:

| | Sonnet 5 | Haiku 4.5 |
| --- | --- | --- |
| cache write | $0.012262 | — |
| cache read | $0.001044 | $0.000540 |

The gap between writing and reading on Sonnet is a factor of twelve. This
confirms the main cost rule: a working cache matters more than the choice of
tier. Hence the decision to run `cache-canary.js` after any change to prompts,
rather than "when we remember to".

## 2026-08-25. Escalating from a smaller model to a larger one

Proposal on the table: give the task to Haiku, escalate to Sonnet when it gets
stuck, and have Opus check the result regardless. Worked through with the numbers
above, for a typical loop (~30k-token stable prefix, ~15 steps):

| | Haiku 4.5 | Sonnet 5 | Opus 5 |
| --- | --- | --- | --- |
| one attempt | ~$0.14 | ~$0.31 | ~$0.70 |

A Haiku attempt costs 0.45 of a Sonnet attempt, so the ladder beats
Sonnet-only when Haiku solves more than **45%** of incidents on its own. Without
a working cache the same arithmetic puts the break-even near 70%, where the
ladder almost certainly loses — so caching is a precondition for the ladder, not
an add-on to it.

Three corrections to the shape of it:

- **Opus must never run unconditionally.** An unconditional Opus pass adds $0.70
  to every incident against a $0.31 baseline — three times today's cost at any
  success rate. Opus is the last rung, not a final reviewer.
- **A model cannot switch itself.** Which model runs is decided by the workflow
  before the run starts; an instruction in the prompt cannot change it. The
  ladder lives in the orchestration.
- **"Stuck" must be judged objectively.** A weaker model frequently does not know
  it failed and will report success. The CI verdict is the available objective
  signal, and the auto-fix loop already keys on it.

Also: escalation must hand over a **summary**, not a transcript. Each tier has
its own cache, so a handover inflates the prefix the stronger model has to write
at 12.5x the read price, and it drags the weaker model's dead ends along.

Decision: not yet settled. What is needed first is per-attempt logging of model
and actual cost from `/api/v1/generation`, because the real success rate is
currently unknown and the ladder would otherwise be a guess.

## 2026-08-25. Constraints of the target environment

Verified on the project's working server (4 cores, 8 GB RAM): Docker is present,
Java and the Android SDK are not. Consequence for the pipeline: **the APK is
built in CI only**; there is no local build of the mobile half, and instructions
must not assume one.

On spend accounting: an ordinary OpenRouter key does not return a per-model
breakdown — `/api/v1/activity` needs a provisioning key. But
`/api/v1/generation?id=` is readable with an ordinary key and returns the actual
cost of a specific call. That is enough for the canary to report what the provider
charged instead of what a price list implies.
