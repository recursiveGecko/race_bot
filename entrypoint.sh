#!/bin/bash

set -xe

echo "::: Running migrations and starting the release :::"

bin/f1bot eval 'F1Bot.Release.migrate()'
exec bin/f1bot start
