# Add an SSH session interface with a dartssh2 implementation

The first of three tasks that together give the app its add-a-server flow. This
one is only the transport: something the orchestrator in the next task can call,
and that tests can replace. It builds nothing the user can see.

Supersedes the withdrawn oversized task in `01-ssh-bootstrap-and-deploy.md`,
which asked for the transport, the orchestration and three screens at once and
ran out of turns having pushed nothing.

## What is already decided

**An interface, with `dartssh2` behind it — the shape `SecretStore` already
uses.** `dartssh2` opens sockets, so any code touching it directly can only be
tested on a device, and the orchestration this exists to serve is precisely what
must be testable on the host. `app/lib/services/secret_store.dart` is the
pattern: abstract interface, one real implementation, one in-memory fake used by
tests.

**`app/tool/ssh_bootstrap_probe.dart` is the reference.** It was written to
answer whether `dartssh2` covers this chain at all, and it proved every primitive
against the pinned version: password auth, remote exec, ed25519 generation via
`pinenacl`, PEM round-trip, SFTP upload, `authorized_keys` append, and reconnect
by key alone. Lift its `authorizedKeysLine` encoding rather than rewriting it —
the SSH wire format is length-prefixed strings, not the raw 32 bytes, and getting
it wrong produces a line `sshd` silently ignores, which then looks like an
authentication bug. Do not delete or modify the probe.

## What to build

`app/lib/services/ssh_session.dart`:

- An abstract interface covering exactly what bootstrap needs and nothing more:
  run a command and get back exit code plus stdout and stderr, upload bytes to a
  path, close. Reading stderr is not optional — a failed `docker compose up` says
  everything useful there, and a bootstrap that reports only "it failed" is the
  thing this design exists to avoid.
- A way to open a session by password and a way to open one by key, since the
  whole point of the bootstrap is moving from the first to the second.
- The `dartssh2` implementation.
- Ed25519 key generation, returning both the `authorized_keys` line and a PEM the
  key store can hold, so the caller never handles raw key bytes.
- A scripted fake, in `lib/` beside the real one rather than in `test/`: the next
  task's tests need it too, and a fake that lives in one test file gets copied
  into the second. It answers a queue of expected commands, records what it was
  asked, and fails a test loudly when asked something unexpected — a fake that
  silently returns success for an unanticipated command would make the
  orchestrator's tests prove nothing.

## What must not change

- No new dependencies. `dartssh2` and `pinenacl` are already in
  `app/pubspec.yaml`.
- Nothing in `.github/`, `scripts/check-secrets.sh` or `.gitignore`.
- No screen, no orchestration, no profile or secret-store changes. Those are the
  next two tasks.
- Nothing may log a password, a private key or a command containing either.

## Acceptance

```
cd app && dart format --output=none --set-exit-if-changed lib test tool
cd app && flutter analyze
cd app && flutter test
```

Tests, all host-only with no network: the `authorized_keys` line for a known key
has the exact expected bytes, including the length prefixes; a generated key
survives export to PEM and back; the fake returns queued results in order,
records the commands it saw, and throws on an unexpected command rather than
succeeding.

Push the branch as soon as `ssh_session.dart` analyzes clean, before writing the
tests. Then keep pushing.
