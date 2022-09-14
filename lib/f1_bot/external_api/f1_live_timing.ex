defmodule F1Bot.ExternalApi.F1LiveTiming do
  @moduledoc false
  @finch_instance F1Bot.Finch
  @api_base "https://livetiming.formula1.com/static/"

  def session_info(base_url \\ @api_base) do
    url = api_url(base_url, "SessionInfo.json")

    request(:get, url)
    |> parse_json_response()
  end

  def current_archive_url_if_completed() do
    with {:ok, response} <- session_info(),
         %{"Status" => "Complete"} <- response["ArchiveStatus"],
         path when path != nil <- response["Path"] do
      url =
        @api_base
        |> URI.merge(path)
        |> URI.to_string()

      {:ok, url}
    else
      nil -> {:error, :nil_archive_path}
      %{} -> {:error, :unacceptable_archive_status}
      {:error, err} -> {:error, err}
    end
  end

  def session_status(base_url) do
    url = api_url(base_url, "SessionStatus.json")

    request(:get, url)
    |> parse_json_response()
  end

  def archive_list(year) do
    url = api_url(@api_base, "#{year}/Index.json")
    |> URI.to_string()

    request(:get, url)
    |> parse_json_response()
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

  defp api_url(base_url, endpoint) do
    URI.merge(base_url, endpoint)
  end
end
