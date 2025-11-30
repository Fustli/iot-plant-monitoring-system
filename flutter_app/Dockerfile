# ==============================================================================
# Flutter Web Frontend - Multi-stage Dockerfile
# ==============================================================================
# Stage 1: Build Flutter web app
# Stage 2: Serve with Nginx
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build
# ------------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:3.38.3 AS builder

WORKDIR /app

# Copy pubspec for dependency resolution (pubspec.lock may not exist in fresh repos)
COPY pubspec.yaml ./

# Get dependencies
RUN flutter pub get || true

# Copy the rest of the app
COPY . .

# Build for web with release optimizations
# Note: --web-renderer was removed in Flutter 3.22+, use FLUTTER_WEB_RENDERER env var if needed
RUN flutter build web --release

# ------------------------------------------------------------------------------
# Stage 2: Serve with Nginx
# ------------------------------------------------------------------------------
FROM nginx:alpine AS production

# Install envsubst (gettext) to allow runtime templating of nginx config
RUN apk add --no-cache gettext

# Remove default nginx config
RUN rm -rf /etc/nginx/conf.d/default.conf

# Copy nginx template (we'll substitute BACKEND_HOST into this at container start)
COPY nginx.conf.template /etc/nginx/conf.d/default.conf.template

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Copy built Flutter web app
COPY --from=builder /app/build/web /usr/share/nginx/html

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

# Expose port 80
EXPOSE 80

# Entrypoint will render nginx config and start nginx
ENTRYPOINT ["/docker-entrypoint.sh"]
