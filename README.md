# Race Bot

[![Docs](https://img.shields.io/badge/pages-docs-informational)](https://recursivegecko.github.io/race_bot) 
[![License](https://img.shields.io/github/license/recursiveGecko/race_bot)](LICENSE.md) 
[![Twitter](https://img.shields.io/twitter/follow/LiveRaceBot?style=social)](https://twitter.com/LiveRaceBot)

An [Elixir](https://elixir-lang.org/) project dedicated to processing live data from Formula 1 races.

#### [Guide for end users (Twitter)](https://twitter.com/LiveRaceBot/status/1528040470961692673)

#### [Documentation](https://recursivegecko.github.io/race_bot)

*All product and company names are trademarks™ or registered® trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.*

## License

This project is licensed under GNU Affero General Public License version 3, see `LICENSE.md` for details.

## Basic usage

```bash
# Install dependencies
mix deps.get

# Configuration file `.env` must be created by copying `.env.example`
cp .env.example .env

# Copy .env into your environment variables - the application doesn't read .env file on its own 
# Only works on fish terminal at the moment
source env.fish

# Generate documentation
mix docs

# Run locally
iex -S mix

# Run a backtest on an old session
iex -S mix backtest --url "http://livetiming.formula1.com/static/2022/2022-05-08_Miami_Grand_Prix/2022-05-07_Qualifying"
```

## Intro

To get a general overview of the data flow and processing in this project, you can explore the project in this order:

Example event: `SessionStatus` event with status `started`

1. `F1Bot.ExternalApi.SignalR.Client` receives the event from live timing API
1. `F1Bot.LiveTimingHandlers` determines the handler module for this event
1. `F1Bot.LiveTimingHandlers.SessionStatus` handles parsing/pre-processing
1. `F1Bot.F1Session` passes the event to the running F1 session instance
1. `F1Bot.F1Session.Server` calls the functional code to process this event
1. `F1Bot.F1Session.Impl` updates its state with new session status and returns an event that represents a side effect
1. `F1Bot.F1Session.Server` broadcasts the event via `F1Bot.PubSub`
1. `F1Bot.Output.Twitter` receives the session status change event and composes a Tweet
1. `F1Bot.ExternalApi.Twitter` chooses the configured Twitter client module (live or console for local testing)
1. `F1Bot.ExternalApi.Twitter.Console` outputs composed Tweet ("F1 Session just started") to your console

