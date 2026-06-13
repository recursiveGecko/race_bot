defmodule F1Bot.ExternalApi.SignalRCore.Negotiation do
  @moduledoc """
  HTTP client for SignalR connection negotiation.

  F1 migrated the live timing feed from classic ASP.NET SignalR
  (`/signalr`, `clientProtocol=1.x`, GET negotiate) to ASP.NET Core SignalR
  (`/signalrcore`, `negotiateVersion=1`, POST negotiate). The old endpoint now
  returns HTTP 401. This module implements the Core negotiation.

  Core negotiate protocol:
  https://github.com/dotnet/aspnetcore/blob/main/src/SignalR/docs/specs/TransportProtocols.md
  """
  @finch_instance F1Bot.Finch

  require Logger

  def negotiate(opts) do
    query =
      %{negotiateVersion: "1"}
      |> URI.encode_query()

    base_path = Keyword.fetch!(opts, :base_path)

    url =
      %URI{
        scheme: Keyword.fetch!(opts, :scheme),
        host: Keyword.fetch!(opts, :hostname),
        port: Keyword.fetch!(opts, :port),
        path: "#{base_path}/negotiate",
        query: query
      }
      |> URI.to_string()

    Logger.info("Negotiating SignalR (core) at '#{url}'")

    headers = [
      {"user-agent", Keyword.fetch!(opts, :user_agent)}
    ]

    # SignalR Core negotiate is a POST with an empty body.
    Finch.build(:post, url, headers, "")
    |> Finch.request(@finch_instance, receive_timeout: 5000)
    |> parse_response()
  end

  defp parse_response({:ok, %{status: 200, body: body, headers: headers}}) do
    # F1's load balancer pins the websocket to the same node via the AWSALB
    # cookie returned here, so we must forward it on the websocket upgrade.
    cookies =
      headers
      |> Enum.filter(fn {name, _v} -> String.downcase(name) == "set-cookie" end)
      |> Enum.map(fn {_name, val} -> val end)
      |> Enum.map(fn val -> String.split(val, ";") end)
      |> Enum.map(fn [val | _] -> val end)
      |> Enum.map(fn val -> String.split(val, "=", parts: 2) end)
      |> Enum.map(fn [name, value] -> {name, value} end)
      |> Enum.into(%{})

    parsed = Jason.decode!(body)

    # Core negotiate (version 1) returns `connectionToken` which must be used as
    # the `id` query param on the websocket, plus a `connectionId`.
    conn_token = Map.fetch!(parsed, "connectionToken")
    conn_id = Map.get(parsed, "connectionId", conn_token)

    response = %{
      data: %{
        "ConnectionId" => conn_id,
        "ConnectionToken" => conn_token
      },
      cookies: cookies
    }

    {:ok, response}
  end

  defp parse_response({:ok, %{status: status, body: body}}) do
    Logger.error("SignalR negotiate failed: HTTP #{status} #{inspect(body)}")
    {:error, {:negotiate_http_error, status}}
  end

  defp parse_response({:error, reason}) do
    Logger.error("SignalR negotiate request error: #{inspect(reason)}")
    {:error, reason}
  end
end
