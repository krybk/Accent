# Accent

An Android remote for server-side AI infrastructure.

You add a server to the app — address, port, root credentials — and the app
deploys a container stack onto it: a gateway, a model router, a database. From
then on you talk to that server from a chat: text, images, files, video, voice
messages. You can add several servers and ask them to be linked to each other
with keys or tunnels.

In spirit it is AmneziaVPN, except what gets deployed is AI infrastructure rather
than a tunnel.

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

Early development. Done: repository hygiene and a prompt-caching check. In
progress: the gateway, server profiles, text chat.

## Models

Haiku, Sonnet and Opus are reachable through the gateway, as are third-party
models — directly or via OpenRouter, switchable from the UI. Spend is accounted
per call, which turned out to matter more than the choice of tier: the money goes
into resending history, not into the length of answers. Measurements and
conclusions are in [`.claude/journal.md`](.claude/journal.md).

To verify that prompt caching actually works:

```
OPENROUTER_API_KEY=... node scripts/cache-canary.js anthropic/claude-sonnet-5
```

## Pipeline template

The repository also serves as the template for subsequent apps: the scaffolding
(`.github/`, `scripts/`, `.claude/`) carries over wholesale, while the
application half (`app/`, `gateway/`) is rewritten. The split is documented in
[`CLAUDE.md`](CLAUDE.md).
