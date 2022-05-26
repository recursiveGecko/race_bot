defmodule F1Bot.ExternalApi.F1LiveTiming do
  @moduledoc false
  @finch_instance F1Bot.Finch

  def session_status() do
    with {:ok, url} <- api_url("SessionStatus.json") do
      request(:get, url)
      |> parse_json_response()
    end
  end

  def request(method, full_url) do
    Finch.build(method, full_url)
    |> Finch.request(@finch_instance)
  end

  defp parse_json_response({:ok, %{body: body}}) when is_binary(body) do
    body
    |> String.replace_prefix("\uFEFF", "")
    |> Jason.decode()
  end

  defp parse_json_response({:error, error}) do
    {:error, error}
  end

  defp api_url(endpoint) do
    endpoint = String.trim_leading(endpoint, "/")

    case api_base() do
      {:ok, base} ->
        path = base <> endpoint
        {:ok, path}

      {:error, _e} ->
        {:error, :failed_to_acquire_api_base}
    end
  end

  defp api_base() do
    case F1Bot.api_base() do
      {:ok, path} -> {:ok, path}
      {:error, _} -> {:error, :uninitialized_session_info}
    end
  end
end
