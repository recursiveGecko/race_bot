defmodule F1Bot.ExternalApi.SignalR.Encoding do
  @moduledoc """
  Decoding & decompression functions for inflating certain live timing API data feeds (e.g. telemetry)
  """

  def decode_live_timing_data(base64_encoded_compressed_json) do
    with {:ok, decoded} <- Base.decode64(base64_encoded_compressed_json),
         {:ok, decompressed} <- safe_zlib_unzip(decoded),
         {:ok, data} <- Jason.decode(decompressed) do
      {:ok, data}
    else
      :error -> {:error, :base64_decoding_error}
      {:error, error} -> {:error, error}
    end
  end

  def safe_zlib_unzip(data) do
    try do
      data = :zlib.unzip(data)
      {:ok, data}
    rescue
      _e -> {:error, :zlib_error}
    end
  end
end
