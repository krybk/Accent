#!/usr/bin/env bash
# Builds and starts caddy, gateway and postgres under a throwaway compose
# project and proves that the pinned CA root completes TLS to the gateway, that
# the gateway token is enforced, that /v1/plane/* is forwarded, that LiteLLM
# stays down without a provider key and /v1/chat says so, and that a per-device
# token file admits its token until it is deleted.
set -euo pipefail
cd "$(dirname "$0")/.."

project=accent-smoke
port="${SMOKE_PORT:-18443}"
host="${SMOKE_HOST:-127.0.0.1}"
expect_plane="${SMOKE_EXPECT_PLANE:-0}"

workdir=$(mktemp -d)
chmod 700 "$workdir"
env="$workdir/env"
root="$workdir/root.crt"
body="$workdir/body"
auth="$workdir/auth"
auth2="$workdir/auth2"
compose=(docker compose -p "$project" --env-file "$env" -f gateway/docker-compose.yml)

rand() { openssl rand -base64 36 | tr '+/' '-_'; }

cleanup() {
  "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

token=$(rand)
umask 077
cat >"$env" <<EOF
GATEWAY_TOKEN=$token
LITELLM_MASTER_KEY=$(rand)
POSTGRES_PASSWORD=$(rand)
GATEWAY_PORT=$port
GATEWAY_HOST=$host
PLANE_SOCKET_DIR=${PLANE_SOCKET_DIR:-/run/accent-plane}
EOF
chmod 600 "$env"
printf 'Authorization: Bearer %s\n' "$token" >"$auth"
chmod 600 "$auth"

fail() {
  echo "FAIL: $1"
  "${compose[@]}" logs --no-color --tail 40 caddy gateway || true
  exit 1
}
ok() { echo "ok: $1"; }

get() {
  local path=$1 code
  shift
  code=$(curl -sS --cacert "$root" --max-time 20 -o "$body" -w '%{http_code}' \
    "$@" "https://$host:$port$path" 2>/dev/null) || code=000
  echo "${code: -3}"
}

"${compose[@]}" up -d --build caddy || fail 'stack did not start'

SECONDS=0
until "${compose[@]}" exec -T gateway /app/bin/healthcheck >/dev/null 2>&1; do
  [ "$SECONDS" -lt 300 ] || fail 'gateway not healthy within 300 s'
  sleep 5
done

SECONDS=0
until "${compose[@]}" exec -T caddy cat /data/caddy/pki/authorities/local/root.crt \
  >"$root" 2>/dev/null && grep -q 'BEGIN CERTIFICATE' "$root"; do
  [ "$SECONDS" -lt 30 ] || fail 'no CA root'
  sleep 2
done

code=$(get /live)
if [ "$code" = 200 ] && [ "$(cat "$body")" = ok ]; then
  ok "GET /live -> 200"
else
  fail "GET /live -> $code (want 200 with body ok)"
fi

code=$(get /v1/models)
[ "$code" = 401 ] || fail "GET /v1/models without auth -> $code (want 401)"
ok "GET /v1/models without auth -> 401"

code=$(get /v1/models -H @"$auth")
[ "$code" = 200 ] || fail "GET /v1/models with auth -> $code (want 200)"
ok "GET /v1/models with auth -> 200"

running=$("${compose[@]}" ps --services --status running)
if grep -qx litellm <<<"$running"; then
  fail 'litellm is running without a provider key'
fi
ok 'litellm not started without a provider key'

code=$(get /v1/chat -H @"$auth" -H 'content-type: application/json' \
  -X POST --data '{"model":"sonnet","messages":[]}')
[ "$code" = 503 ] || fail "POST /v1/chat -> $code (want 503)"
grep -q chat_not_configured "$body" ||
  fail 'POST /v1/chat body lacks chat_not_configured'
ok 'POST /v1/chat -> 503 chat_not_configured'

# A second, per-device token: only its hash enters the gateway.
t2=$(rand)
h=$(printf %s "$t2" | sha256sum | cut -d' ' -f1)
printf 'Authorization: Bearer %s\n' "$t2" >"$auth2"
chmod 600 "$auth2"
"${compose[@]}" exec -T gateway sh -c \
  "mkdir -p /var/lib/accent/tokens.d && printf 'sha256:%s\n' $h > /var/lib/accent/tokens.d/smoke" ||
  fail 'could not write a token file'
code=$(get /v1/models -H @"$auth2")
[ "$code" = 200 ] || fail "GET /v1/models with a token file -> $code (want 200)"
ok 'GET /v1/models with a token file -> 200'

"${compose[@]}" exec -T gateway rm /var/lib/accent/tokens.d/smoke ||
  fail 'could not remove the token file'
code=$(get /v1/models -H @"$auth2")
[ "$code" = 401 ] || fail "GET /v1/models after deleting the token file -> $code (want 401)"
ok 'GET /v1/models after deleting the token file -> 401'
code=$(get /v1/models -H @"$auth")
[ "$code" = 200 ] || fail "GET /v1/models with the env token -> $code (want 200)"
ok 'GET /v1/models with the env token still -> 200'

code=$(get /v1/plane/status -H @"$auth")
if [ "$expect_plane" = 1 ]; then
  [ "$code" = 200 ] || fail "GET /v1/plane/status -> $code (want 200)"
  ok "GET /v1/plane/status -> 200"
elif [ "$code" = 200 ]; then
  ok "GET /v1/plane/status -> 200"
elif [ "$code" = 404 ]; then
  ok "GET /v1/plane/status -> 404 (no plane socket)"
else
  fail "GET /v1/plane/status -> $code (want 200 or 404)"
fi

ok 'stack smoke passed'
