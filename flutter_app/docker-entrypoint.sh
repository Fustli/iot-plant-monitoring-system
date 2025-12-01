#!/bin/sh
# Simple entrypoint for templating nginx config with BACKEND_HOST and starting nginx

: "${BACKEND_HOST:=backend}"

# Replace variable in the nginx config template
envsubst '$BACKEND_HOST' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Dump resolved config to stdout for troubleshooting
echo "[entrypoint] Generated nginx config at /etc/nginx/conf.d/default.conf"
echo "[entrypoint] BACKEND_HOST=$BACKEND_HOST"
echo "[entrypoint] ---- BEGIN nginx config ----"
cat /etc/nginx/conf.d/default.conf || echo "[entrypoint] (failed to read config)"
echo "[entrypoint] ----  END nginx config  ----"

# Start nginx in foreground
exec nginx -g 'daemon off;' 
