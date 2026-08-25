# Tasks

A task is a file here. Pushing one to `main` files an Issue, and the Issue goes
through the ordinary path: a session implements it, opens a pull request, and the
merge closes the Issue. [`tasks.yml`](../workflows/tasks.yml) does the filing.

The file, not the Issue, is the specification. If the two disagree the file wins,
because it is the one that was reviewed in a diff.

## Writing one

- First line must be `# Title`. It becomes the Issue title, so it should read as
  an instruction rather than a topic.
- Say what is already decided and why, not just what to build. A specification
  that leaves the architecture open gets whatever the session guesses, and the
  guess arrives as a merged pull request.
- Say what must not change. Bounding the blast radius is worth more than
  describing the happy path.
- Give the acceptance check in commands, so "done" is not a judgement call.

## Pushing one

One at a time, unless two tasks genuinely cannot touch the same files. Pull
requests from `auto/` branches merge unread once CI is green, and two of them
editing one screen will merge in whichever order finishes first.

Deduplication is by the `<!-- task: path -->` marker in the Issue body, so a
re-push or a revert cannot file the same task twice. Editing a task file after
its Issue exists changes nothing — file a new task instead.
