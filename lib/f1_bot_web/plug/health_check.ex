defmodule F1BotWeb.HealthCheck do
  import Plug.Conn

  def init(opts), do: opts |> Enum.into(%{})

  def call(%Plug.Conn{request_path: path} = conn, _opts = %{path: path}) do
    conn
    |> send_resp(200, "OK")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
