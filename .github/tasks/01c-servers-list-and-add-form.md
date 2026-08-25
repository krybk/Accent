# Wire the servers list to storage and add the form for a new server

Third of the bootstrap tasks. The transport landed in #7 and the orchestrator in
#9; both are unreachable from the UI, because `ServersScreen` is still the shell
it was written as — its add button shows a snackbar saying the flow does not
exist.

This task is the list and the form. Driving the bootstrap and showing its
progress is the next task; keep the two apart, because a screen that both
collects input and runs a ten-stage process is the kind of file that cannot be
tested.

## What exists to build on

`ProfileRepository`: `list()`, `save(profile)`, `forget(id)`, and the secret
accessors. `ServerProfile` with `id`, `name`, `host`, `username`, `port`,
`gatewayPort`, `bootstrapped`, and `gatewayUri`. `SecretStore` with
`InMemorySecretStore` for tests.

`SshBootstrap.run({profile, password, openRouterApiKey})` returns
`Stream<BootstrapEvent>`, and `RootPassword` wraps the password so it can be
released and then throws if read again. This task does not call `run` — it only
has to reach the point where the next screen can.

## What is already decided

**The form collects: name, host, port, username, root password, provider key.**
The first four go on the profile; the last two do not. `OPENROUTER_API_KEY` is
required because the stack declares it `:?` in compose and will not start
without it, and the password is required because bootstrap begins with it. The
form is where both are typed and the only place they exist.

**The password never becomes a field on anything that persists.** It is not on
`ServerProfile`, deliberately, so that it cannot be printed. Hand it onward as
`RootPassword` and let the widget's state drop it; do not store it, log it, or
put it in a snackbar.

**The profile is created and saved before bootstrap runs.** With
`bootstrapped: false`, which is what the flag is for — the profile is an
intention until the stack answers. That is also what makes an interrupted
bootstrap resumable: the profile and its id already exist, and the secrets are
keyed by that id.

**The id is generated, not derived from the host.** Renaming or re-addressing a
server would otherwise orphan its key material. Any collision-free scheme is
fine as long as it does not depend on host or name.

**A list row shows whether the server is bootstrapped**, because an unfinished
profile that looks identical to a working one is how someone ends up debugging a
chat screen that was never going to connect.

## What to build

- `app/lib/screens/add_server_screen.dart` — the form, with validation: host
  non-empty, port in range, username non-empty, password non-empty, provider key
  non-empty. On submit it saves the profile and returns it, together with the
  password and provider key, to the caller. It does not navigate onward itself;
  the caller decides, and that keeps this screen testable without the next one.
- `ServersScreen` rewritten against `ProfileRepository`: real list, the existing
  empty state when there is nothing, an add button that opens the form. The
  snackbar goes away. Take the repository as a constructor parameter so a test
  can pass one backed by `InMemorySecretStore` — do not reach for a global.
- `main.dart` builds the repository once and passes it in.

## What must not change

- No new dependencies.
- Nothing in `.github/`, `scripts/check-secrets.sh` or `.gitignore`.
- Do not modify `ssh_session.dart`, `ssh_bootstrap.dart`, `profile_repository.dart`
  or `server_profile.dart`. If one needs an addition, add rather than rewrite,
  and say so in the pull request.
- Do not start the bootstrap from these screens. That is the next task.

## Acceptance

```
cd app && dart format --output=none --set-exit-if-changed lib test tool
cd app && flutter analyze
cd app && flutter test
```

Widget tests, no network: the empty state shows when the repository is empty; a
saved profile appears in the list with its bootstrapped state visible; the form
rejects each invalid field with a message naming that field; a valid submission
saves a profile with `bootstrapped: false` and returns the password and provider
key to the caller; and neither the password nor the provider key appears in any
rendered widget or in the saved profile's JSON.

The existing `widget_test.dart` asserts the old snackbar behaviour. Update it —
do not delete the file to make the suite pass.
