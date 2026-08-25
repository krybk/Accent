# Implement the SSH bootstrap and bring the stack up on the server

Turn a root password into a deployed stack and a working credential, which is
the step the app is currently missing entirely: `ServersScreen` has an add button
that says the flow does not exist, and nothing in `app/lib/services/` talks to a
server.

The user-visible outcome: enter host, username, password and a model provider
key; watch named stages complete; end with a profile whose `bootstrapped` is
true, a private key and gateway token in the Android Keystore, and a stack
answering `/v1/health` over pinned TLS.

## What is already decided

Do not re-litigate these. Each one was settled by reading the code that exists.

**Deploy by cloning this repository on the server, at a pinned ref.** Not by
uploading a bundle. `gateway/docker-compose.yml` builds the gateway from source
(`build.context: ..`), so a bundle would mean shipping the gateway and protocol
sources inside the APK as assets and keeping them from drifting. The repository
is public, the server needs outbound network anyway for images and model calls,
and a pinned ref makes a deploy reproducible. Pin to the app's own version from
`app/pubspec.yaml` when a matching tag exists, otherwise `main`, and record which
in the progress log.

**Generate the secrets on the phone and write them into `gateway/.env`.** Do not
generate them server-side and read them back. `GATEWAY_TOKEN`,
`LITELLM_MASTER_KEY` and `POSTGRES_PASSWORD` are 32+ random characters each —
`GatewayConfig` refuses to start on a token shorter than 32. The token then never
has to be read out of a file over SSH, and the app already knows it. `README.md`
currently describes the opposite order ("issues a token; fetches the token");
correct that prose in this pull request.

**`OPENROUTER_API_KEY` has to be collected in the form.** Compose declares it
`:?`, so the stack will not start without it. It is a secret: keystore, not a
profile field.

**Pin Caddy's internal CA root, not the leaf.** Read it once bootstrap is up
with `docker compose exec -T caddy cat /data/caddy/pki/authorities/local/root.crt`
and store it as this profile's pinned certificate. `tls internal` in
`gateway/caddy/Caddyfile` is why there is a CA to pin at all.

**Abstract the SSH transport behind an interface, the way `SecretStore` is.**
`dartssh2` opens sockets, so anything calling it directly can only be tested on a
device. Put a narrow interface in front — connect, run a command, upload a file,
close — with the `dartssh2` implementation in one file and a scripted fake in the
tests. `app/tool/ssh_bootstrap_probe.dart` already proves every primitive works
against this version of the library, including the exact `authorized_keys` wire
encoding; lift that encoding rather than rewriting it, and delete nothing from
the probe.

**Progress is a stream of named stages, not a spinner.** Bootstrap takes minutes,
touches a stranger's server and can fail at a dozen points; "something went
wrong" after four minutes is not a usable failure. Each stage reports start,
success or a failure carrying what actually failed.

**Re-running must be safe.** A bootstrap interrupted halfway leaves a key
installed, or a clone present, or containers up. Every step checks before acting:
appending the public key twice is a bug, and so is refusing to continue because
the repository is already cloned.

## What to build

- `app/lib/services/ssh_session.dart` — the interface and its `dartssh2`
  implementation.
- `app/lib/services/ssh_bootstrap.dart` — the orchestrator, emitting stages.
- `app/lib/screens/add_server_screen.dart` — the form.
- `app/lib/screens/bootstrap_screen.dart` — stage list with per-stage state.
- Wire `ServersScreen` to `ProfileRepository`: real list, real empty state, add
  button that opens the form. Its current snackbar goes away.

The stages, in order: connect with the password; generate an ed25519 key; install
the public half in `authorized_keys`; reconnect with the key alone and confirm
the password is no longer needed; install Docker if `docker compose version`
fails; clone or update the repository at the pinned ref; write `gateway/.env`;
`docker compose -f gateway/docker-compose.yml up -d --build`; wait for the stack
to answer its own health endpoint on the server; read the CA root; store key,
token, provider key and certificate; mark the profile bootstrapped. The password
is wiped from memory the moment key-only login is confirmed, and never written
anywhere.

## What must not change

- No new dependencies. `dartssh2`, `pinenacl`, `flutter_secure_storage` and
  `http` are already in `app/pubspec.yaml` and are sufficient.
- Nothing in `.github/`, `scripts/check-secrets.sh` or `.gitignore`.
- No secret may reach a profile object, a log line or an exception message. The
  password especially: it is deliberately not a field on `ServerProfile` so that
  it cannot be printed.
- `protocol/` and `gateway/` are not part of this task.

## Acceptance

From the repository root, all of these pass:

```
dart format --output=none --set-exit-if-changed protocol gateway
cd app && dart format --output=none --set-exit-if-changed lib test tool
cd app && flutter analyze
cd app && flutter test
```

Tests must cover, against the scripted fake and with no network: the full
happy-path stage sequence; a failure at each of connect, key install, Docker
install and compose up, asserting the failing stage is the one reported; that
re-running against a server which already has the key and the clone succeeds
without duplicating either; and that no code path puts the password into a
stored value, a profile or an error message.

Add an entry to `docs/known-failures.md` only if something genuinely new failed
while building this.
