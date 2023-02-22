defmodule MapUtils do
  @doc """
  Patches the old map or struct, ignoring nil values in the new map
  """
  def patch_ignore_nil(old, new) when is_map(old) and is_map(new) do
    {original_struct, old_map, new_map} = prepare_for_merge(old, new)

    merged =
      Map.merge(old_map, new_map, fn _k, a, b ->
        if b == nil do
          a
        else
          b
        end
      end)

    if original_struct do
      struct!(original_struct, merged)
    else
      merged
    end
  end

  @doc """
  Patches the old map, only changing fields that were nil
  """
  def patch_missing(old, new) when is_map(old) and is_map(new) do
    {original_struct, old_map, new_map} = prepare_for_merge(old, new)

    merged =
      Map.merge(old_map, new_map, fn _k, a, b ->
        if a != nil do
          a
        else
          b
        end
      end)

    if original_struct do
      struct!(original_struct, merged)
    else
      merged
    end
  end

  defp prepare_for_merge(old, new) when is_map(old) and is_map(new) do
    old_map = if is_struct(old), do: Map.from_struct(old), else: old
    new_map = if is_struct(new), do: Map.from_struct(new), else: new

    case {old, new} do
      {%struct{}, %struct{}} ->
        {struct, old_map, new_map}

      {%struct{}, new} when not is_struct(new) ->
        {struct, old_map, new_map}

      {old, %_struct{}} when not is_struct(old) ->
        {nil, old_map, new_map}

      {old, new} when not (is_struct(old) or is_struct(new)) ->
        {nil, old_map, new_map}

      _ ->
        raise "Structs must be the same type. Attempted to patch #{inspect(old.__struct__)} with #{inspect(new.__struct__)}"
    end
  end
end
