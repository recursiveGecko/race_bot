#!/bin/bash

set -xe

# Fix permissions in Docker Desktop (https://github.com/docker/for-win/issues/2476)
chown -R app:app /data

echo "::: Running migrations and starting the release :::"

setpriv --reuid=app --regid=app --clear-groups /app/bin/f1bot eval 'F1Bot.Release.migrate()'
exec setpriv --reuid=app --regid=app --clear-groups /app/bin/f1bot start
