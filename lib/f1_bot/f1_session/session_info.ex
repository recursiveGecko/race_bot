defmodule F1Bot.F1Session.SessionInfo do
  @moduledoc """
  Stores and handles changes to current session information.
  """
  use TypedStruct

  alias F1Bot.F1Session.Common.Event

  @api_base_path "http://livetiming.formula1.com/static/"

  typedstruct do
    @typedoc "F1 Session Info"

    field(:gp_name, String.t())
    field(:type, String.t())
    field(:www_path, String.t())
    field(:start_date, DateTime.t())
    field(:end_date, DateTime.t())

    field(:lap_number, pos_integer() | nil)
  end

  def new do
    %__MODULE__{}
  end

  def parse_from_json(json) do
    utc_offset =
      Map.fetch!(json, "GmtOffset")
      |> String.split(":")
      |> Enum.take(2)
      |> Enum.join(":")

    utc_offset =
      if String.starts_with?(utc_offset, "-") do
        utc_offset
      else
        "+" <> utc_offset
      end

    {:ok, start_date, _} =
      (Map.fetch!(json, "StartDate") <> utc_offset)
      |> DateTime.from_iso8601()

    {:ok, end_date, _} =
      (Map.fetch!(json, "EndDate") <> utc_offset)
      |> DateTime.from_iso8601()

    data = %{
      start_date: start_date,
      end_date: end_date,
      type: Map.fetch!(json, "Name"),
      gp_name: get_in(json, ["Meeting", "Name"]),
      www_path: @api_base_path <> Map.fetch!(json, "Path")
    }

    struct!(__MODULE__, data)
  end

  def update(
        old = %__MODULE__{},
        new = %__MODULE__{}
      ) do
    name_match = old.gp_name == new.gp_name
    session_match = old.type == new.type

    session_changed? = not name_match or not session_match

    old = Map.from_struct(old)
    new = Map.from_struct(new)

    merged = Map.merge(old, new)
    session_info = struct!(__MODULE__, merged)

    session_info =
      if session_changed? do
        reset_counters(session_info)
      else
        session_info
      end

    events = [Event.new(:session_info, :session_info_changed, session_info)]

    {session_info, events, session_changed?}
  end

  def push_lap_number(
        session_info = %__MODULE__{lap_number: old_lap_number},
        lap_number
      ) do
    lap_number =
      cond do
        is_integer(old_lap_number) and is_integer(lap_number) and lap_number > old_lap_number ->
          lap_number

        not is_integer(old_lap_number) and is_integer(lap_number) ->
          lap_number

        true ->
          old_lap_number
      end

    %{session_info | lap_number: lap_number}
  end

  def is_race?(session_info) do
    session_info.type == "Race"
  end

  def reset_counters(session_info) do
    %__MODULE__{session_info | lap_number: nil}
  end
end