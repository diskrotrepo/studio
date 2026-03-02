# -------- Build stage --------------------------------------------------------
# Build context must be packages/ (parent dir) for workspace resolution.
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /workspace

# Copy workspace root pubspec + lock
COPY pubspec.yaml pubspec.lock ./

# Copy both package pubspecs (workspace resolution needs all members)
COPY studio_backend/pubspec.yaml studio_backend/pubspec.yaml
COPY studio_ui/pubspec.yaml studio_ui/pubspec.yaml

RUN cd studio_ui && flutter pub get

# Copy UI source and build for web
COPY studio_ui/ studio_ui/

ARG BUILD_ENV=local
ARG BUILD_DATE
ARG BUILD_BRANCH
RUN cd studio_ui && flutter build web --release --pwa-strategy=none --dart-define=BUILD_ENV=${BUILD_ENV} --dart-define=BUILD_DATE=${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)} --dart-define=BUILD_BRANCH=${BUILD_BRANCH:-dev}

# -------- Serve stage --------------------------------------------------------
# nginxinc/nginx-unprivileged runs as non-root (uid 101) on port 8080
FROM nginxinc/nginx-unprivileged:alpine

COPY --from=build /workspace/studio_ui/build/web /usr/share/nginx/html

# SPA fallback + cache headers
RUN printf 'server {\n\
    listen 8080;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    # index.html must always be revalidated so the browser picks up new builds\n\
    location = /index.html {\n\
        add_header Cache-Control "no-cache";\n\
    }\n\
    # Hashed assets (main.dart.js, *.part.js, fonts, images) — cache for 1 year\n\
    location /assets/ {\n\
        add_header Cache-Control "public, max-age=31536000, immutable";\n\
    }\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
