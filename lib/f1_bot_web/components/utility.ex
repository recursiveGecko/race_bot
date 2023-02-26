defmodule F1BotWeb.Component.Utility do
  use F1BotWeb, :component
  alias Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~F"""
    """
  end

  @doc """
  Push a partial params object to the client to be merged into the
  existing params stored in localStorage. Sent to the server when connection
  is re-established.
  Use for saving the user's preferences such as the selected drivers and
  live data delay.
  """
  def save_params(socket, params = %{}) do
    socket
    |> LiveView.push_event("save-params", params)
  end
end
