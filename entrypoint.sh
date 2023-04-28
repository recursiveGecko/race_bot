#!/bin/bash

set -xe

cd "/app/_build/${MIX_ENV}/rel/f1bot"

echo "::: Running migrations and starting the release :::"

bin/f1bot eval 'F1Bot.Release.migrate()'
exec bin/f1bot start
