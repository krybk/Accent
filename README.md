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
4. reconnects with the key alone, and drops the password there and then;
5. installs Docker if missing and clones this repository at a pinned ref;
6. generates the gateway token itself, writes it into the stack's `.env`, and
   brings the stack up;
7. reads the certificate the stack issued itself.

The token is generated **on the phone** and handed to the server, not the other
way round: nothing then has to read a credential back out of a file over SSH, and
the app already holds the one it will present. The certificate is the reverse —
it is the server's own, so it is read once and pinned.

After that the app only ever talks to the gateway — over TLS, with a token and a
pinned certificate. A stolen phone does not grant root, and the token can be
revoked from the server.

Adding the same server twice is safe. Each step checks before it acts, so an
interrupted bootstrap can simply be run again: the key is not appended a second
time, an existing clone is fetched rather than refused, and the stack keeps the
password its database was initialised with.

## Status

Version 0.1.0 is released: the signed APKs are on
[v0.1.0](https://github.com/krybk/Accent/releases/tag/v0.1.0), and
[Installing and adding a server](#installing-and-adding-a-server) says how to
set one up.

Standing up: the gateway (config, auth, routing, upstream requests, a container
stack that builds and answers a liveness probe), the shared `protocol` package
(model catalogue, chat types), and on the app side server profiles with their
key material kept in the Android Keystore, plus the SSH bootstrap that deploys
the stack onto a server. 161 tests across the three packages.

CI runs four gates on every pull request and every push to `main`: a secret
scan, the two Dart packages, the Flutter app including a debug APK build, and
the gateway image.

The app also drives the bootstrap on a progress screen, and shows the plane and
per-model token usage through a pinned, token-authenticated gateway client.
The chat screen talks to a model on the server, streams the answer as it is
written and carries the conversation on from one message to the next. Any
message can be sent to an open plan as guidance; nothing is posted until the
owner presses Send in that dialog. The usage screen also switches each model
tier off and on, and work for a tier that is off runs on its stand-in.
The queue screen lists the open plans in the order they will be taken, and
moves a plan up, down, to the top or to the end, or holds and resumes it.

## Releases

v0.1.0 is the first release. The release workflow triggers on `v*` only, and the
tag is still the trigger: a release is a decision, and the tag is where that
decision is recorded.

Each release needs, in order:

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

## Installing and adding a server

Download from the release page `accent-0.2.0-arm64-v8a.apk`, which fits
practically every current phone, or `accent-0.2.0-universal.apk` if you are
unsure. The `armeabi-v7a` and `x86_64` builds exist for older phones and
emulators.

Verify the download before installing it:

```
sha256sum -c SHA256SUMS.txt --ignore-missing
apksigner verify --print-certs accent-0.2.0-arm64-v8a.apk
```

`apksigner` must print `certificate SHA-256 digest:` followed by the value
below, the certificate shown above under Releases:

```
7b71191348cf05b2b87edb32926652f24974264a2a8304487a7da0c5e2fa5a7c
```

Android asks once to allow the browser or file manager that opens the APK to
install unknown apps (Settings → Apps → Special app access → Install unknown
apps). Later versions install over this one as long as they carry the same
signature.

To add a server, press the **Add a server** button on the servers screen; the
screen it opens is titled "Add a server" too. Fill in:

- **Name** — optional, the host is used when left blank;
- **Host**;
- **SSH port**;
- **Username**;

and, under "Used once, never stored":

- **Root password** — the bootstrap installs a key with it and then drops it;
- **Anthropic API key** — optional. Chat goes through the control plane and
  does not need it; only the stack's own `/v1/chat` uses it. Without it the
  stack starts without LiteLLM.

Then press **Save the server**. The app opens "Deploying the stack" and ticks
through its stages. On success it shows "The server is ready" and **Done**; on
failure "The bootstrap failed" and **Close**. Adding the same server again is
safe (see [How access works](#how-access-works)). The server then shows as
"Bootstrapped" in the list.

Before deploying anything, the bootstrap looks, read-only, at what the server
already runs, and takes one of three paths:

1. **A running Accent gateway** (a container labelled
   `accent.gateway.tokens-dir`). The app joins it without rebuilding or
   restarting anything, and without reading or writing `/opt/accent` or any
   `.env`: it pins the CA of that gateway's Caddy, uses the port Caddy
   publishes, and writes its own token file under `/var/lib/accent/tokens.d`
   in the gateway container. The file holds only the SHA-256 of the token; the
   token itself stays on the phone. Each app gets its own file, named by its
   server profile, so adding the same server again rewrites that file. The
   server must be added under the address the gateway's certificate is issued
   for (its `GATEWAY_HOST`); any other address is refused.
2. **A control plane socket at `/run/accent-plane/plane.sock` and no
   gateway.** The stack is deployed as in the third case, with the gateway
   attached to that socket.
3. **Neither.** The stack is deployed: the steps in the numbered list under
   [How access works](#how-access-works), with the stack in `/opt/accent`.

If another container already publishes the gateway port, the bootstrap stops
before starting anything and names that container.

To revoke one app's access to a shared gateway, list the token files and delete
that app's file; `ls -l` shows when each was written:

```
docker exec <gateway container> ls -l /var/lib/accent/tokens.d
docker exec <gateway container> rm /var/lib/accent/tokens.d/<file>
```

Other apps keep working.

Tapping the server opens:

- **Plane** — the plane's state;
- **Usage** — per-model token usage, with switches to turn each model tier off
  and on (work for a tier that is off runs on its stand-in);
- **Chat** — a streamed conversation with a model on the server, any message
  can be sent to an open plan as guidance;
- **Queue** — open plans in the order they will be taken, moved up, down, to
  the top or to the end, held and resumed.

## Models

Sonnet and Opus are reachable through the gateway, which calls the Anthropic API
directly with the server's own `ANTHROPIC_API_KEY`. The key is
entered when the server is added, kept in the phone's secure storage, and
written to that server's `.env` during bootstrap. Spend is accounted per call,
which turned out to matter more than the choice of tier: the money goes into
resending history, not into the length of answers. Measurements and
conclusions are in [`docs/engineering-journal.md`](docs/engineering-journal.md).

To verify that prompt caching actually works:

```
ANTHROPIC_API_KEY=... node scripts/cache-canary.js claude-sonnet-5-5
```
