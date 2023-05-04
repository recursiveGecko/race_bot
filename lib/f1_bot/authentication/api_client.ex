defmodule F1Bot.Authentication.ApiClient do
  use Ecto.Schema
  import Ecto.Changeset

  @secret_bytes 64
  @scopes [
    :transcriber_service,
    :read_transcripts
  ]

  schema("api_client") do
    field(:client_name, :string)
    field(:client_secret, :string)
    field(:scopes, {:array, Ecto.Enum}, values: @scopes)
  end

  def create_changeset(data \\ %__MODULE__{}, params) do
    data
    |> cast(params, [:client_name, :scopes])
    |> validate_required([:client_name, :scopes])
    |> put_change(:client_secret, generate_secret())
  end

  def update_changeset(data, params) do
    data
    |> cast(params, [:scopes])
    |> validate_required([:scopes])
  end

  def generate_secret() do
    :crypto.strong_rand_bytes(@secret_bytes)
    |> Base.encode64(padding: false)
  end

  def verify_secret(this = %__MODULE__{}, provided_secret) do
    try do
      # Constant time comparison
      :crypto.hash_equals(this.client_secret, provided_secret)
    rescue
      _e -> false
    end
  end

  def token(this = %__MODULE__{}) do
    "#{this.client_name}:#{this.client_secret}"
  end
end
