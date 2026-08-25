# Add the bootstrap orchestrator that deploys the stack over SSH

Second of three. The transport landed in `app/lib/services/ssh_session.dart`
(#7); this is the sequence that uses it to turn a root password into a deployed
stack and a stored credential. No UI — that is the third task.

## What exists to build on

`SshSessionFactory` with `connectWithPassword` and `connectWithKey`;
`SshSession.run` returning `SshCommandResult` with `exitCode`, `stdout` and
`stderr`; `SshSession.upload`; `GeneratedSshKey.generate()` giving a
`privateKeyPem` and an `authorizedKeysLine`. For tests,
`ScriptedSshSessionFactory` and `ScriptedSshSession`, which throw
`UnexpectedSshRequest` on a command the script did not anticipate.

Also `ProfileRepository`, `SecretStore` and `ServerProfile` — already in place,
with `bootstrapped` on the profile and secrets kept under the profile's `id`.

## What is already decided

**Deploy by cloning this repository on the server at a pinned ref.** Not by
uploading a bundle: `gateway/docker-compose.yml` builds the gateway from source
(`build.context: ..`), so a bundle would mean shipping the gateway and protocol
sources inside the APK and keeping them from drifting. The repository is public,
the server needs outbound network anyway for images and model calls, and a pinned
ref makes a deploy reproducible. Use the app's own version from `pubspec.yaml` as
a `v`-prefixed tag when the server reports it exists, otherwise `main`, and put
which one was used into the progress log.

**Generate the secrets on the phone and write them into `gateway/.env`.** Not
generated server-side and read back. `GATEWAY_TOKEN`, `LITELLM_MASTER_KEY` and
`POSTGRES_PASSWORD` are 32+ random characters from a cryptographic source —
`GatewayConfig` refuses to boot on a token under 32. The token then never has to
be read out of a file over SSH, and the app already holds it. `README.md`
describes the opposite order today ("issues a token; fetches the token") — fix
that prose here.

**`OPENROUTER_API_KEY` is an input, not a generated value.** Compose declares it
`:?` and the stack will not start without it. It is a secret: it goes to the key
store, never to a profile field.

**Pin Caddy's internal CA root, not the leaf.** Read it once the stack is up:
`docker compose exec -T caddy cat /data/caddy/pki/authorities/local/root.crt`.
`tls internal` in `gateway/caddy/Caddyfile` is why there is a CA to pin.

**Progress is a stream of named stages.** Bootstrap takes minutes, touches
someone's server and can fail at a dozen points; "something went wrong" after
four minutes is not a usable failure. Each stage reports start, then success or a
failure carrying the command's `stderr` — that is what `SshCommandResult` keeps
it for.

**Re-running must be safe.** An interrupted bootstrap leaves a key installed, or
a clone present, or containers up. Check before acting: appending the public key
twice is a bug, and so is refusing to continue because the clone already exists.

## What to build

`app/lib/services/ssh_bootstrap.dart` — the orchestrator and its stage types.
Nothing else. The stages, in order:

1. connect with the password;
2. generate the key, install the public half in `authorized_keys` if not already
   present;
3. reconnect with the key alone, confirming the password is now unnecessary —
   and drop the password from memory here, not later;
4. install Docker if `docker compose version` fails;
5. clone or fast-forward the repository at the pinned ref;
6. write `gateway/.env`;
7. `docker compose -f gateway/docker-compose.yml up -d --build`;
8. poll the stack's own health endpoint on the server until it answers or a
   bounded number of attempts runs out;
9. read the CA root;
10. store key, token, provider key and certificate under the profile's id, and
    mark the profile bootstrapped.

## What must not change

- No new dependencies.
- Nothing in `.github/`, `scripts/check-secrets.sh` or `.gitignore`.
- No screens. `ServersScreen` stays as it is.
- `ssh_session.dart` is not to be rewritten. If it needs an addition, add.
- No secret in a log line, an exception message, a profile or a progress event.
  The password especially — it is deliberately not a field on `ServerProfile` so
  that it cannot be printed.

## Acceptance

```
cd app && dart format --output=none --set-exit-if-changed lib test tool
cd app && flutter analyze
cd app && flutter test
```

Tests, host-only, driven by `ScriptedSshSessionFactory`: the happy path emits the
stages in order and ends with the profile bootstrapped and every secret stored; a
failure injected at connect, at key install, at Docker install and at compose up
each reports that stage as the failing one and stops; a second run against a
server that already has the key and the clone succeeds without appending the key
twice; the generated token is at least 32 characters; and no stored value,
progress event or error message anywhere contains the password.

Push the branch as soon as the file analyzes clean, before the tests. Then keep
pushing.
