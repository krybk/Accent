# Build context is the repository root, not gateway/, because the gateway
# depends on ../protocol by path. A context of gateway/ alone cannot see it.
#
# The SDK version is pinned rather than `stable`: the lockfile is resolved by a
# specific SDK, and a floating base image silently re-resolves dependencies on
# some future build. See .dockerignore for why the host's .dart_tool must not
# reach this context.

FROM dart:3.13 AS build
WORKDIR /src

# Manifests first, so editing code does not invalidate the dependency layer.
COPY protocol/pubspec.yaml protocol/
COPY gateway/pubspec.yaml gateway/pubspec.lock gateway/
RUN cd gateway && dart pub get --no-precompile

# Source second. The resolution from the layer above survives, because
# .dockerignore keeps the host's .dart_tool out of the context — so there is no
# second `pub get` here, and no chance of it re-resolving to different versions.
COPY protocol/ protocol/
COPY gateway/ gateway/

# AOT to native binaries: no VM start-up cost, no source on the running host,
# and a runtime image that needs no Dart SDK at all.
RUN mkdir -p /out \
  && cd gateway \
  && dart compile exe bin/server.dart -o /out/server \
  && dart compile exe bin/healthcheck.dart -o /out/healthcheck

# Slim runtime with no Dart toolchain. Only ca-certificates, which the outbound
# TLS to the model provider needs.
FROM debian:stable-slim AS runtime
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/server /app/bin/server
COPY --from=build /out/healthcheck /app/bin/healthcheck

# Runs as root only because the Docker socket is root-owned. Narrowing this is
# tied to putting a socket proxy in front, not to a uid change here.
WORKDIR /app
EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
