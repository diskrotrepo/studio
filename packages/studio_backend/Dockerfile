# -------- Build stage --------------------------------------------------------
# Build context must be packages/ (parent dir) for workspace resolution.
FROM dart:stable AS build

WORKDIR /workspace

# Copy workspace root pubspec + lock first for layer caching
COPY pubspec.yaml pubspec.lock ./

# Copy only the backend pubspec — rewrite workspace to exclude studio_ui
# so dart pub get doesn't try to resolve Flutter SDK dependencies.
COPY studio_backend/pubspec.yaml studio_backend/pubspec.yaml

RUN sed -i 's/- studio_ui//' pubspec.yaml \
    && cd studio_backend && dart pub get

# Copy backend source and compile
COPY studio_backend/ studio_backend/

ARG BUILD_DATE
ARG BUILD_BRANCH
RUN cd studio_backend && dart compile exe bin/server.dart -o bin/server \
    -DBUILD_DATE=${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)} \
    -DBUILD_BRANCH=${BUILD_BRANCH:-dev}

# -------- Runtime stage ------------------------------------------------------
FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates ffmpeg curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /runtime/ /runtime/
COPY --from=build /workspace/studio_backend/bin/server /usr/local/bin/server

ENV PORT=80

RUN useradd -r -u 1001 -g root -s /sbin/nologin appuser
USER 1001

CMD ["/usr/local/bin/server"]
