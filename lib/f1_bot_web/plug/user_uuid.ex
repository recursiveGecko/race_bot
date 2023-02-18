defmodule F1BotWeb.Plug.UserUUID do
  alias Ecto.UUID
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_session(conn)
    user_uuid = get_session(conn, :user_uuid)

    if user_uuid == nil do
      conn
      |> put_session(:user_uuid, UUID.generate())
    else
      conn
    end
  end
end
