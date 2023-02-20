# Race Bot

[![Docs](https://img.shields.io/badge/pages-docs-informational)](https://recursivegecko.github.io/race_bot) 
[![License](https://img.shields.io/github/license/recursiveGecko/race_bot)](LICENSE.md) 
[![Twitter](https://img.shields.io/twitter/follow/LiveRaceBot?style=social)](https://twitter.com/LiveRaceBot)

An [Elixir](https://elixir-lang.org/) project dedicated to processing live data from Formula 1 races.

[Project's Website](https://racing.recursiveprojects.cloud/) displays live telemetry and analysis (Work in progress).

[Development & Demo Website](https://racing-dev.recursiveprojects.cloud/) displays telemetry of previous events to demonstate the functionality.

#### [Guide for end users (Twitter)](https://twitter.com/LiveRaceBot/status/1528040470961692673)

#### [Documentation](https://recursivegecko.github.io/race_bot)

*All product and company names are trademarks™ or registered® trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.*

## Requirements

* [Elixir 1.14+](https://elixir-lang.org/install.html)
* [NodeJS 16+](https://nodejs.org/en/) to install NPM dependencies

Alternatively you can use `asdf` to manage tool versions, but be aware that it builds Erlang from source which 
[requires installation of additional system dependencies](https://github.com/asdf-vm/asdf-erlang#before-asdf-install).

## Basic usage

```bash
# Install dependencies
mix setup

# Configuration file `.env` must be created by copying `.env.example`
cp .env.example .env

# Copy .env into your environment variables - the application doesn't read .env file on its own 
# Only works on fish terminal at the moment
source env.fish

# Generate documentation
mix docs

# Run locally
iex -S mix phx.server

# Run a backtest on an old session
iex -S mix backtest --url "http://livetiming.formula1.com/static/2022/2022-05-08_Miami_Grand_Prix/2022-05-07_Qualifying"
```

## Intro

To get a general overview of the data flow and processing in this project, you can explore the project in this order:

Example packet: `SessionStatus` packet with status `started`

1. `F1Bot.ExternalApi.SignalR.Client` receives the packet from live timing API
1. `F1Bot.F1Session.Server` calls the functional code to process this `Packet`
1. `F1Bot.F1Session.LiveTimingHandlers` determines and calls the handler module for this packet
1. `F1Bot.F1Session.LiveTimingHandlers.SessionStatus` calls `F1Session` function to update the state
1. `F1Bot.F1Session` updates its state with new session status and returns its new state + a 'session status change' event
1. `F1Bot.F1Session.Server` broadcasts the event via `F1Bot.PubSub`
1. `F1Bot.Output.Twitter` receives the session status change event and composes a Tweet
1. `F1Bot.ExternalApi.Twitter` chooses the configured Twitter client module (live or console for local testing)
1. `F1Bot.ExternalApi.Twitter.Console` outputs composed Tweet ("F1 Session just started") to your console

## Contributing

Pull requests, bug reports and feature suggestions are welcome!

## Thanks

💙 [theOehrly/Fast-F1](https://github.com/theOehrly/Fast-F1): For inspiration, their effort and
documentation. Fast-F1 was extremely valuable in quickly understanding how F1's live timing service works. 

💙 [MultiViewer for F1](https://github.com/f1multiviewer): For tyre icons used in this project

## License

This project is licensed under GNU Affero General Public License version 3, see `LICENSE.md` for details.
