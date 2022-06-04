defprotocol F1Bot.LightCopy do
  @doc """
  Recursively copies data with heavy bits (e.g. telemetry and position history) removed.
  Structs containing heavy data must implement the protocol and strip the data.
  """
  @fallback_to_any true
  def light_copy(data)
end

defimpl F1Bot.LightCopy, for: Any do
  alias F1Bot.LightCopy

  def light_copy(data) when is_list(data) do
    Enum.map(data, &LightCopy.light_copy/1)
  end

  def light_copy(%module{} = data) when is_struct(data) do
    map =
      data
      |> Map.from_struct()
      |> LightCopy.light_copy()

    struct(module, map)
  end

  def light_copy(%{} = data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, LightCopy.light_copy(v)} end)
    |> Enum.into(%{})
  end

  def light_copy(data) do
    data
  end
end
