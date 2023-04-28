defmodule F1Bot.Time do
  @doc """
  Equivalent to Timex.between?/3 except it treats nil `from_ts` and `to_ts`
  values as negative and positive infinity

  ## Examples

    iex> F1Bot.Time.between?(
    ...>   Timex.from_unix(10),
    ...>   Timex.from_unix(5),
    ...>   nil
    ...> )
    true

    iex> F1Bot.Time.between?(
    ...>   Timex.from_unix(10),
    ...>   nil,
    ...>   Timex.from_unix(15)
    ...> )
    true

    iex> F1Bot.Time.between?(
    ...>   Timex.from_unix(10),
    ...>   nil,
    ...>   nil
    ...> )
    true

    iex> F1Bot.Time.between?(
    ...>   Timex.from_unix(10),
    ...>   Timex.from_unix(1000),
    ...>   Timex.from_unix(2000)
    ...> )
    false
  """
  @spec between?(DateTime.t(), DateTime.t() | nil, DateTime.t() | nil) ::
          boolean()
  def between?(ts, from_ts, to_ts) do
    cond do
      from_ts == nil and to_ts == nil ->
        true

      from_ts == nil ->
        Timex.before?(ts, to_ts)

      to_ts == nil ->
        Timex.after?(ts, from_ts)

      true ->
        Timex.between?(ts, from_ts, to_ts)
    end
  end

  def unix_timestamp_now(precision) when precision in [:second, :millisecond] do
    DateTime.utc_now()
    |> DateTime.to_unix(precision)
  end
end
