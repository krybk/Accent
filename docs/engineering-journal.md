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

## 2026-08-25. Stack changed from Tauri to Flutter, after a probe

I originally recommended Tauri v2 + React, leaning on "one stack for the whole
pipeline". That argument turned out to be weaker than it sounded: nothing in
`.github/`, `scripts/` or `docs/` depends on the app's language, and
`CLAUDE.md` already declares `app/` and `gateway/` as rewritten per app. The
template's value is in the scaffolding, so changing the client language costs it
nothing.

Flutter also erases the two risks named in the plan as most likely to cost time.
Secure key storage stops being a hand-written Kotlin plugin over Android Keystore
and becomes `flutter_secure_storage`; voice capture stops being a fight with
WebView permissions and becomes the `record` package. Image, video and file
pickers are equally off-the-shelf, which turns most of milestone 2 into assembly
rather than binding-writing.

The one real unknown was SSH in pure Dart, so it was probed rather than assumed —
`dartssh2` 2.22.5 against a throwaway local account, all seven links of the
bootstrap chain:

| Step | Result |
| --- | --- |
| connect with password | pass |
| run a remote command | pass |
| generate an ed25519 key | pass (32 B public, 64 B private) |
| export to PEM and read back | pass |
| upload a file over SFTP | pass |
| append to authorized_keys | pass |
| reconnect using the key alone | pass |

Two API facts worth keeping, because both would otherwise be rediscovered the
hard way:

- **dartssh2 reads keys but does not generate them.** There is no
  `SSHKeyPair.generate`. Build the key yourself and hand
  `OpenSSHEd25519KeyPair` the raw bytes. Use `pinenacl` for it — that is the same
  ed25519 implementation dartssh2 signs with, so no second crypto library enters
  the tree. The private half must be the 64-byte seed‖public form, not the bare
  32-byte seed.
- **An authorized_keys line needs SSH wire format**, not the raw 32 bytes:
  length-prefixed `"ssh-ed25519"` followed by the length-prefixed key, then
  base64 of that. Get it wrong and sshd ignores the line in silence, which
  presents as a dartssh2 authentication bug rather than an encoding bug.

Probe kept at `app/tool/ssh_bootstrap_probe.dart`: it is the skeleton the real
bootstrap grows from, and it encodes both gotchas above in working form.

**Follow-up the same day: the gateway moved to Dart too.** My first version of
this entry listed "a third language in the pipeline" as the cost of the decision.
That cost was self-inflicted — it only exists if the gateway stays Rust. Checked
the server-side story rather than assuming: `shelf` has 8.7M downloads in 30 days
at 160/160 pub points, `postgres` 556k at 160/160. Mature enough.

So Dart on both sides, plus a shared `protocol` package. The real win is not
saving a language, it is that request and response types are shared code: a
protocol change breaks compilation instead of production. Rust would have bought
nothing measurable here — the gateway is I/O-bound, proxying streams and running
Docker commands — while costing a hand-maintained duplicate of every type.
Anything genuinely CPU-heavy (speech-to-text) runs in its own container anyway.

**Still open:** the probe ran against `dartssh2` 2.22.5 because the pubspec
pinned `^2.14.0`, while 3.3.1 is current. Re-verify the chain on 3.x when
scaffolding the app; do not assume the API is unchanged across a major version.

Timing made the whole switch cheap: no application code existed yet.

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

## 2026-08-25. dartssh2 3.3.1 separates stdout from stderr for you

Building the SSH session interface meant reading the pinned `dartssh2` 3.3.1
source rather than trusting the probe, which had run against 2.22.5. One API fact
changes how remote commands should be run, and it is not the obvious path:

- **`SSHClient.run` returns the two streams merged.** Its own doc says "combined
  command output", and the probe uses it — fine for a probe that only needs to
  see something come back. For a bootstrap it is the wrong call: a failed
  `docker compose up` says everything useful on stderr, and merged output cannot
  be reported as a cause.
- **`SSHClient.runWithResult` exists in 3.x and returns
  `SSHRunResult(output, stdout, stderr, exitCode, exitSignal)`.** So there is no
  reason to drop to `execute()` and collect the channels by hand — which is the
  shape you land on if you assume `run` is all there is. Doing it by hand also
  invites a real bug the package already handles: the two stream completions must
  be awaited together, because awaiting one and then the other leaves the second
  without an error handler until the first finishes, turning a stream error into
  an uncaught one.

`exitCode` is `int?`. Null means the process died on a signal or the server sent
no exit status. Both are failures for our purposes, so the app folds null into
`-1` rather than pushing a null check onto every caller whose two branches would
be identical.

Also settled while pinning the encoding by test: the base64 of a correct
`ssh-ed25519` blob always begins `AAAAC3NzaC1lZDI1NTE5AAAAI`, because the first
19 bytes are fixed (the length-prefixed algorithm name, then the length 32). That
prefix is a free external check on the wire format — if a line does not start
with it, the encoding is wrong, and no server is needed to find out.

**What this does not close:** the open item from the probe entry above asked for
the *chain* to be re-verified on 3.x. This was an API-level check against the
pinned source plus host-only tests. Password auth, SFTP and reconnect-by-key have
not been re-run against a live server on 3.3.1.

## 2026-08-25. What the bootstrap sequence cannot assume about a server

Writing the orchestrator turned up four things that are not visible in the
compose file or the SSH interface, each of which would have surfaced as a
mysterious failure on someone's server rather than as a compile error.

**Postgres sets its password only when it initialises its volume.** So a second
bootstrap that generates a fresh `POSTGRES_PASSWORD` writes a `.env` the existing
database rejects, and the gateway and LiteLLM can no longer log in to their own
storage. A repair run would break a working stack. The phone therefore keeps
`LITELLM_MASTER_KEY` and `POSTGRES_PASSWORD` alongside the gateway token, even
though it never presents either of them — it is the only party that can keep them
stable across runs, since the decision not to read secrets back off the server
also means not reading these.

The same argument applies to the SSH key, one level up: generating a fresh key on
every run leaves the previous public half in `authorized_keys` forever, granted to
a private half the phone has already thrown away. The key is read back out of the
store and reused, and it is persisted as soon as the key-only connection proves it
works — not in the last stage. A crash between those two points would otherwise
orphan a credential that still grants root and that nothing will ever rotate.

**Neither `curl` nor `git` is guaranteed to be present.** Docker's convenience
script needs `curl` to be downloaded at all, so `curl` exists on any server we
installed Docker on — but not necessarily on one that already had it. And that
script installs Docker, not `git`. Two consequences: the health poll runs the
gateway container's own health-check binary (`docker compose exec -T gateway
/app/bin/healthcheck`) rather than curling the published port, and the checkout
stage begins with an idempotent one-liner that tries `apt-get`, then `dnf`, then
`apk`. Docker itself is the one tool that can be assumed, because the stage before
guarantees it.

Using the container's own health check has a second benefit that was the deciding
one: it hits the unauthenticated liveness path, so the gateway token never
appears in a command line. A command line is world-readable in `ps` on the
server, which rules out `curl -H "Authorization: Bearer …"` and rules out writing
`.env` with `echo`. It goes up over SFTP instead.

**`git ls-remote --exit-code` reserves exit 2 for "no matching refs".** Anything
else — 128, typically — is a transport failure. Without that distinction, "is
there a `v0.1.0` tag?" answers "no" on a server with no network, and the bootstrap
silently deploys `origin/main` when it was asked for a release. The stage stops on
a non-2 failure instead.

**A `String` cannot be wiped in Dart.** Strings are immutable, so "wipe the
password from memory" can only mean dropping the last reference to it — and a
parameter cannot be dropped, because its frame lives as long as the bootstrap
does. The password therefore travels in a `RootPassword` box that is emptied
during stage 3, with seven stages and several minutes still to run, and asking for
it afterwards throws. This is a smaller guarantee than "overwritten", and the
difference is worth stating rather than papering over.

One analyzer detail worth remembering, since the fix looks like noise: assigning
an awaited generic call into a nullable local makes inference pick the nullable
type parameter, so the value never promotes and every later use is an error. The
sessions are held in nullable locals for cleanup and in non-nullable locals for
work, which is why both exist.
