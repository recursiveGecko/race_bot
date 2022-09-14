FROM elixir:1.13-slim

ENV MIX_ENV=prod

RUN apt-get update && \
    apt-get install -y build-essential cmake erlang-dev gnuplot

RUN mix local.hex --force && mix local.rebar --force

RUN mkdir /app
WORKDIR /app

ADD mix.exs /app
ADD mix.lock /app
RUN mix deps.get && mix deps.compile

ADD . /app 
RUN mix assets.deploy && mix release

RUN useradd -m app
RUN chown -R app:app /app
USER app

ENTRYPOINT ["/app/_build/prod/rel/f1bot/bin/f1bot"]
CMD ["start"]