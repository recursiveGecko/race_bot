defmodule F1BotWeb.Layouts do
  use F1BotWeb, :html

  embed_templates "layouts/*"

  def phx_host() do
    F1Bot.get_env(F1BotWeb.Endpoint)[:url][:host]
  end
end
