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
rather than cheap (details in `docs/engineering-journal.md`).

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

## Android release build fails at `checkReleaseAarMetadata`

**Symptom.** `Dependency ':flutter_secure_storage' requires ... version 37 or
later of the Android APIs. :app is currently compiled against android-36.`

**Cause.** `flutter.compileSdkVersion` resolves lower than a plugin requires.

**Fix.** Pin `compileSdk` explicitly in `app/android/app/build.gradle.kts`.
`compileSdk` only decides which APIs are available at compile time — `minSdk`
and `targetSdk` are untouched, so the set of devices that can install the app
does not change.

## `minifyReleaseWithR8` fails on missing Play Core classes

**Symptom.** `Missing class com.google.android.play.core.splitinstall.*`,
referenced from `io.flutter.embedding.engine.deferredcomponents`.

**Cause.** Flutter's embedding references Play Core for Play-Store-delivered
deferred components. We distribute APKs directly, so those classes are not on
the classpath and R8 refuses references it cannot resolve.

**Fix.** `-dontwarn com.google.android.play.core.**` in `proguard-rules.pro`.
Correct rather than a workaround: those code paths are unreachable in a
directly-installed build. If the app ever ships through the Play Store with
deferred components, the rule must go and the dependency must come in.

## `Gradle build daemon disappeared unexpectedly`

**Symptom.** The build dies partway with no OOM message and no indication that
memory was involved. Most likely on the universal APK, where R8 processes every
architecture at once.

**Cause.** The Flutter template ships `org.gradle.jvmargs=-Xmx8G
-XX:MaxMetaspaceSize=4G` — 12 GB of reservation, on machines that often have 8 GB
in total.

**Fix.** Lower it. Measured on this project: killed at 8G, completes at 4G.

**Do not revisit:** raising the heap to make a different failure go away. If a
build dies without an OOM message, suspect the reservation exceeding physical
memory before suspecting it being too small.

## `flutter build` fails on `dot-shorthands` in generated code

**Symptom.** `This requires the experimental 'dot-shorthands' language feature to
be enabled`, pointing at `lib/main.dart` lines nobody wrote by hand.

**Cause.** `flutter create` generates a template using a language feature newer
than the SDK floor declared in `pubspec.yaml`.

**Fix.** Either raise the SDK constraint or do not use the shorthand. We chose
the latter: a lower floor means the app builds across a wider range of SDKs, and
the generated counter demo was going to be replaced anyway.

## `flutter build apk --debug` fails with "Release signing is not configured"

**Symptom.** The debug build — the one CI runs — dies during Gradle
configuration with the message about missing `key.properties`, on a build that
signs nothing.

**Cause.** The check was written inside `buildTypes { release { ... } }`. That
block is evaluated on the configuration pass for *every* invocation, not only
when a release task runs, so `throw GradleException` there fails `assembleDebug`
as well. A guard meant to protect releases disabled the only Android check CI
has.

**Fix.** Leave `signingConfig` null when the material is absent and hang the
check off the task graph instead: `gradle.taskGraph.whenReady` plus a match on
`^(assemble|bundle|package)\w*Release$`. Verified both ways — `--debug` builds,
`--release` still refuses.

**Do not revisit:** any variant that decides inside the `release` block. The
block's evaluation is unconditional; no condition written there can distinguish
which task was requested.

## Nothing runs at all — no workflow runs in the repository's history

**Symptom.** Actions lists the workflows as active, `total_count` from
`/actions/runs` is 0, and `main` is not being tested by anything.

**Cause.** `ci.yml` carried `pull_request` and `workflow_call` triggers but no
`push`, copied from a repository where a separate build workflow invoked it
through `workflow_call`. No such caller exists here, so nothing ever invoked it.

**Fix.** Add `push: branches: [main]`. With no `workflow_call` caller there is no
double-run to worry about. Keep the standalone `pull_request` trigger: a workflow
invoked via `workflow_call` produces no run of its own and therefore no
`workflow_run` event, which is what the auto-fix loop listens for.

## `Auto-Fix Loop Monitor` fails on a commit whose CI was green

**Symptom.** `handle-ci-result` is red immediately, at the first script step,
often with `Parameter token or opts.auth is required`.

**Cause.** Two independent problems presenting as one. First, the job woke on
CI runs from `push`, where there is no PR to merge or comment on. Second,
`secrets.AUTOMATION_TOKEN` was not set, and `actions/github-script` given an
empty token fails with a message that names nothing actionable.

**Fix.** Gate the PR job on `github.event.workflow_run.event == 'pull_request'`,
handle push failures in a separate job that files an Issue, and check the secret
in an explicit step so the log names it.

**Do not revisit:** substituting `secrets.GITHUB_TOKEN`. It authenticates, so
the job goes green — and the comment or Issue it writes triggers no further
workflow, so `claude.yml` never wakes and the loop silently does nothing. Green
and broken is worse than red.

## "Claude encountered an error" on an Issue, with nothing else said

**Symptom.** `claude.yml` reaches the action and fails there. The Issue gets a
comment saying only that an error occurred. The job log's real line is:
`Environment variable validation failed: Either ANTHROPIC_API_KEY,
CLAUDE_CODE_OAUTH_TOKEN, or workload identity federation ... is required when
using direct Anthropic API.`

**Cause.** A model key that is not set. The action maps its
`anthropic_api_key` input to `ANTHROPIC_API_KEY`, so an empty
`secrets.OPENROUTER_API_KEY` fails validation before any model call. The message
is misleading twice over: it names three alternatives that are irrelevant here —
we authenticate to OpenRouter, not to Anthropic directly — and it never says
which secret is empty.

**Fix.** Set `OPENROUTER_API_KEY`. A step now checks it and `AUTOMATION_TOKEN`
up front and names whichever is missing.

**Reading a log without admin rights:** the check-run annotations are public on a
public repository, and they carry the error line. `curl -s
".../check-runs/$JOB_ID/annotations"`, where `$JOB_ID` comes from
`.../actions/runs/$RUN_ID/jobs`. The `.../jobs/$JOB_ID/logs` endpoint answers
`403 Must have admin rights` — the annotations one does not.

## `./scripts/check-secrets.sh` fails CI

**Symptom.** The run fails on the secrets step.

**Cause.** A key in a known format, or a file from the forbidden list (`.env`,
`*.pem`, `*.jks`, a private SSH key), reached the index.

**Fix.** Remove the file from the index (`git rm --cached`) and add the path to
`.gitignore`. If the secret already reached a published commit, deleting the file
is not enough: **the key must be revoked and reissued**, because the history is
public.
