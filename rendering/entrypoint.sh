#!/bin/sh
set -eu

mkdir -p /run/renderd
mkdir -p /var/cache/renderd/tiles

renderd -f -c /etc/renderd.conf &
RENDERD_PID=$!

trap 'kill "$RENDERD_PID" 2>/dev/null || true' TERM INT

apache2ctl -D FOREGROUND &
APACHE_PID=$!

wait "$APACHE_PID"
STATUS=$?

kill "$RENDERD_PID" 2>/dev/null || true
wait "$RENDERD_PID" 2>/dev/null || true

exit "$STATUS"
