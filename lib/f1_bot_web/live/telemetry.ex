defmodule F1BotWeb.Live.Telemetry do
  use F1BotWeb, :live_view
  alias F1BotWeb.Component
  alias F1Bot.DataTransform.Format

  data session_clock, :any, default: nil
  data session_info, :any, default: nil
  data driver_list, :list
  data drivers_of_interest, :list, default: [1, 11, 16, 55]

  def mount(_params, _session, socket) do
    F1Bot.PubSub.subscribe("state_machine:driver:list")
    F1Bot.PubSub.subscribe("state_machine:driver:summary")
    F1Bot.PubSub.subscribe("state_machine:session_info:session_info_changed")
    F1Bot.PubSub.subscribe("state_machine:session_info:session_clock")

    socket =
      socket
      |> Surface.init()
      |> load_data()

    {:ok, socket}
  end

  defp load_data(socket) do
    maybe_assign = [
      {:driver_list, F1Bot.Cache.driver_list()},
      {:session_clock, F1Bot.Cache.session_clock()},
      {:session_info, F1Bot.Cache.session_info()}
    ]

    maybe_assign
    |> Enum.filter(fn {_, {result_type, _}} -> result_type == :ok end)
    |> Enum.reduce(socket, fn {key, {:ok, val}}, socket -> assign(socket, key, val) end)
  end

  @impl true
  def handle_event("toggle-driver", params, socket) do
    driver_no = String.to_integer(params["driver-number"])
    is_doi = driver_no in socket.assigns.drivers_of_interest

    drivers_of_interest =
      if is_doi do
        Enum.reject(socket.assigns.drivers_of_interest, &(&1 == driver_no))
      else
        [driver_no | socket.assigns.drivers_of_interest]
      end

    socket = assign(socket, :drivers_of_interest, drivers_of_interest)

    {:noreply, socket}
  end

  @impl true
  def handle_info(e = %{scope: :driver, type: :summary}, socket) do
    Component.DriverSummary.handle_summary_event(e)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :driver, type: :list, payload: driver_list},
        socket
      ) do
    socket = assign(socket, driver_list: driver_list)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :session_info, type: :session_clock, payload: session_clock},
        socket
      ) do
    socket = assign(socket, session_clock: session_clock)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :session_info, type: :session_info_changed, payload: session_info},
        socket
      ) do
    socket = assign(socket, session_info: session_info)
    {:noreply, socket}
  end
end
