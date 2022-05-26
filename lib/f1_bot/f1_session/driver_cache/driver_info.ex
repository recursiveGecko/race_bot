defmodule F1Bot.F1Session.DriverCache.DriverInfo do
  @moduledoc """
  Personal information about a driver.
  """
  use TypedStruct

  typedstruct do
    @typedoc "Information about a driver"

    field(:full_name, String.t())
    field(:first_name, String.t())
    field(:last_name, String.t())
    field(:short_name, String.t())
    field(:driver_number, pos_integer())
    field(:driver_abbr, String.t())
    field(:team_color, String.t())
    field(:team_name, String.t())
    field(:picture_url, String.t())
  end

  def parse_from_json(json) do
    data =
      %{
        "FullName" => :full_name,
        "FirstName" => :first_name,
        "LastName" => :last_name,
        "HeadshotUrl" => :picture_url,
        "BroadcastName" => :short_name,
        "RacingNumber" => :driver_number,
        "Tla" => :driver_abbr,
        "TeamColour" => :team_color,
        "TeamName" => :team_name
      }
      |> Enum.reduce(%{}, fn {source, target}, final ->
        if json[source] != nil do
          Map.put(final, target, json[source])
        else
          final
        end
      end)

    struct!(__MODULE__, data)
  end

  def merge(old, new) do
    old = if is_struct(old), do: Map.from_struct(old), else: old
    new = if is_struct(new), do: Map.from_struct(new), else: new

    data =
      Map.merge(old, new, fn _k, v1, v2 ->
        if v2 == nil do
          v1
        else
          v2
        end
      end)

    struct!(__MODULE__, data)
  end
end
