defmodule F1Bot.Cache do
  use GenServer
  require Logger

  @ets_table :f1_bot_cache
  @default_ttl 1_000

  @impl true
  def init(_init_arg) do
    :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def driver_list(), do: fetch(:driver_list)
  def session_clock(), do: fetch(:session_clock)
  def session_info(), do: fetch(:session_info)
  def session_best_stats(), do: fetch(:session_best_stats)

  def driver_summary(driver_no) when driver_no > 0 and driver_no < 100 do
    fetch({:driver_summary, driver_no})
  end

  defp fetch_from_source(:driver_list) do
    F1Bot.driver_list()
  end

  defp fetch_from_source(:session_info) do
    F1Bot.session_info()
  end

  defp fetch_from_source(:session_clock) do
    F1Bot.session_clock()
  end

  defp fetch_from_source(:session_best_stats) do
    F1Bot.session_best_stats()
  end

  defp fetch_from_source({:driver_summary, driver_no}) do
    F1Bot.driver_summary(driver_no)
  end

  defp ttl(:session_clock), do: 1_000
  defp ttl({:driver_summary, driver_no}) when driver_no >= 100, do: 60_000
  defp ttl(_other_keys), do: @default_ttl

  defp expired?(time, ttl) do
    diff =
      DateTime.utc_now()
      |> DateTime.diff(time, :millisecond)

    diff > ttl
  end

  # Fetches the value from the cache, or if it doesn't exist, fetches it from the source
  defp fetch(key) do
    Logger.debug("Fetching #{inspect(key)} from cache")

    case :ets.lookup(@ets_table, key) do
      [{^key, {time, val}}] ->
        {:ok, {time, val}}

      _ ->
        {:error, :cache_miss}
    end
    |> after_fetch(key)
  end

  # If the value was fetched from the source, return it
  defp after_fetch({:ok, {time, val}}, key) do
    if expired?(time, ttl(key)) do
      Logger.debug("Cache expired for #{inspect(key)}, fetching from source")
      refresh_key(key)
    else
      Logger.debug("Cache hit for #{inspect(key)}")
      {:ok, val}
    end
  end

  # If the value wasn't in the cache, fetch it from the source
  defp after_fetch({:error, :cache_miss}, key) do
    refresh_key(key)
  end

  defp refresh_key(key) do
    Logger.debug("Fetching #{inspect(key)} from source")

    case fetch_from_source(key) do
      {:ok, val} ->
        Logger.debug("Fetched #{inspect(key)} from source")

        set_cache(key, val)
        {:ok, val}

      {:error, err} ->
        Logger.debug("Error fetching #{inspect(key)} from source: #{inspect(err)}")
        {:error, err}
    end
  end

  defp set_cache(key, value) do
    Logger.debug("Setting cache for #{inspect(key)}")

    time = DateTime.utc_now()
    :ets.insert(@ets_table, {key, {time, value}})
  end
end
