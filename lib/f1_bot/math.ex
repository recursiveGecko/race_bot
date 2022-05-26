defmodule F1Bot.Math do
  @moduledoc false
  def find_closest_point(point_list, point) do
    Enum.min_by(point_list, &point_distance_3d(point, &1), nil)
  end

  def point_distance_3d(
        %{x: x1, y: y1, z: z1},
        %{x: x2, y: y2, z: z2}
      ) do
    x_delta = x1 - x2
    y_delta = y1 - y2
    z_delta = z1 - z2

    (:math.pow(x_delta, 2) + :math.pow(y_delta, 2) + :math.pow(z_delta, 2))
    |> :math.sqrt()
  end
end
