# Accent

An Android remote for server-side AI infrastructure.

You add a server to the app — address, port, root credentials — and the app
deploys a container stack onto it: a gateway, a model router, a database. From
then on you talk to that server from a chat: text, images, files, video, voice
messages. You can add several servers and ask them to be linked to each other
with keys or tunnels.

## How access works

The root password is entered **once** and is never stored on the device. When you
add a server, the app:

1. connects over SSH with that password;
2. generates a key and puts the private half in the phone's key store;
3. appends the public half to `authorized_keys`;
4. installs Docker if missing, brings the stack up, issues a token;
5. fetches the token and certificate, then wipes the password from memory.

After that the app only ever talks to the gateway — over TLS, with a token and a
pinned certificate. A stolen phone does not grant root, and the token can be
revoked from the server.

## Status

Early development, nothing released yet — see [Releases](#releases) for what
that needs.

Standing up: the gateway (config, auth, routing, upstream requests, a container
stack that builds and answers a liveness probe), the shared `protocol` package
(model catalogue, chat types), and on the app side server profiles with their
key material kept in the Android Keystore. 47 tests across the three packages.

CI runs four gates on every pull request and every push to `main`: a secret
scan, the two Dart packages, the Flutter app including a debug APK build, and
the gateway image. Failures on `main` are picked up without a human — see below.

Still to come: the SSH bootstrap that turns a root password into a deployed
stack, and the chat itself.

## Working through Issues

The repository fixes its own red builds, and takes work by Issue. Open one
mentioning `@claude` and the chain runs to a merge on its own: a session is
started, the fix lands on a branch under `auto/`, a pull request is opened,
labelled, checked, and squash-merged when green, and the Issue is closed by the
merge. A red run on `main` files its own Issue first, titled by the job and step
that failed.

Worth knowing before relying on it:

- Only logins listed in `ALLOWED_AUTHORS` in
  [`claude.yml`](.github/workflows/claude.yml) can start a session. Anyone
  else's Issue costs nothing and is ignored, which matters because this
  repository is public and a session has write access and spends money. Pull
  requests from forks are left to a human for the same reason.
- **A pull request from an `auto/` branch merges unread once CI is green** —
  including changes to the workflows themselves. That is deliberate: the trigger
  wiring lives there, and a loop that cannot repair its own plumbing needs a
  human for every break in it. `scripts/check-secrets.sh` and `.gitignore` stay
  guarded instead, chosen for irreversibility: a bad merge is revertible, a key
  published from a public repository is not.
- One retry, then the Issue gets `needs-human`. That label is the signal that
  automation gave up; a later green run will not clear it.
- Two secrets carry the whole thing: `AUTOMATION_TOKEN`, a PAT with `repo` and
  `workflow` scope, and `OPENROUTER_API_KEY`. Both are checked before a session
  starts so a missing one names itself. If the PAT expires the loop breaks
  quietly — Issues keep being filed and nothing answers them.

Diagnosed failure causes live in
[`docs/known-failures.md`](docs/known-failures.md), which is worth reading
before investigating a red run rather than after.

## Releases

There are none yet, and no tag has been pushed. The release workflow triggers on
`v*` only: a release is a decision, and the tag is where that decision is
recorded.

Publishing a first one needs, in order:

1. **A signing keystore.** Not optional and not something to improvise later. An
   installed Android app can only be upgraded by a build carrying the same
   signature, so a release signed with a throwaway key strands every user who
   installed it — they must uninstall and lose their server profiles. The
   keystore is generated once, backed up somewhere that is not this repository,
   and never committed.
2. **Four secrets**, from that keystore: `ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
   The workflow refuses to run without the first rather than falling back to the
   debug key.
3. **A tag matching `app/pubspec.yaml`.** The workflow compares them and stops
   on disagreement: publishing a `v0.2.0` tag containing `0.1.0` binaries is the
   kind of mistake nobody notices until a user reports the wrong version.

What it then produces: split APKs per architecture plus a universal one, named
by version, with `SHA256SUMS.txt` so a download can be verified independently of
GitHub. Split because a universal APK measures 43 MB against 16 MB for `arm64`
alone — nearly threefold, for no benefit on any single device.

Releases are signed with this certificate:

```
SHA-256  7B:71:19:13:48:CF:05:B2:B8:7E:DB:32:92:66:52:F2:
         49:74:26:4A:2A:83:04:48:7A:7D:A0:C5:E2:FA:5A:7C
CN=Accent, OU=krybk, O=krybk
```

`apksigner verify --print-certs` on a downloaded APK should print exactly that.
`SHA256SUMS.txt` proves a file arrived intact; the signature is what ties it to
whoever built it, and it is the thing an attacker cannot reproduce.

Until a keystore exists, `flutter build apk --release` refuses locally too, by
design; the debug build CI runs is unaffected.

## Models

Haiku, Sonnet and Opus are reachable through the gateway, as are third-party
models — directly or via OpenRouter, switchable from the UI. Spend is accounted
per call, which turned out to matter more than the choice of tier: the money goes
into resending history, not into the length of answers. Measurements and
conclusions are in [`docs/engineering-journal.md`](docs/engineering-journal.md).

To verify that prompt caching actually works:

```
OPENROUTER_API_KEY=... node scripts/cache-canary.js anthropic/claude-sonnet-5
```

## Pipeline template

The repository also serves as the template for subsequent apps: the scaffolding
(`.github/`, `scripts/`, `docs/`) carries over wholesale, while the application
half (`app/`, `gateway/`, `protocol/`) is rewritten. The split is documented in
[`docs/contributing.md`](docs/contributing.md).
