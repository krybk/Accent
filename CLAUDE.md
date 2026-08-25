# Accent

Project conventions live in [`docs/contributing.md`](docs/contributing.md). Read
it before making changes — it holds the stack, the commands, the secret-handling
rules for a public repository, and the measured facts about model cost that
determine which tier to use.

Two files carry the project's memory, and both are worth reading before starting
work rather than after:

- [`docs/engineering-journal.md`](docs/engineering-journal.md) — what was
  measured, what was decided and why, including disproved hypotheses.
- [`docs/known-failures.md`](docs/known-failures.md) — diagnosed causes of CI and
  build failures. Read this **first** when fixing a red run.

## Shared memory across projects

`krybk/aimanager` (private) is the control plane: the merged failure journal for
every repository, the task specification format, and the model routing rules.

Three of its entries were diagnosed twice, independently, here and in `site` — an
action rejecting a model key passed only as `ANTHROPIC_AUTH_TOKEN`, a
`workflow_call` invocation emitting no `workflow_run` event and thereby silencing
everything subscribed to one, and a red run on `main` producing no Issue because
the reporting condition described a narrower failure than the one that happened.
Each rediscovery cost runs.

Two things follow for anyone working here:

- The local `docs/known-failures.md` stays **self-contained**. `aimanager` is
  private, so a session here can only read it through `gh` with
  `AUTOMATION_TOKEN` — extra turns for something diagnosis should never need.
- The shared copy is the aggregate, for a human and for the next project.
  Template syncing does not exist yet, so the two can drift; update both when the
  cause is not specific to Flutter or Android.
