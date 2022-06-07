defmodule F1Bot.ExternalApi.Discord.Permissions do
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Permission

  @doc """
  Checks whether @everyone role has "use external emojis" permission.

  This also determines whether we can use external emojis in slash command responses
  due to Discord not respecting permissions granted via individual roles.

  Discussion of this API limitation: https://github.com/discord/discord-api-docs/issues/2612
  """
  @spec everyone_has_external_emojis?(pos_integer()) :: {:ok, boolean()} | {:error, any()}
  def everyone_has_external_emojis?(guild_id) when is_integer(guild_id) do
    case guild_role_permissions(guild_id, guild_id) do
      {:ok, permissions} ->
        has_perm = :use_external_emojis in permissions
        {:ok, has_perm}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec guild_role_permissions(pos_integer(), pos_integer()) ::
          {:ok, [Permission.t()]} | {:error, any()}
  def guild_role_permissions(guild_id, role_id) when is_integer(guild_id) do
    with {:ok, cache} <- GuildCache.get(guild_id),
         role when is_map(role) <- cache.roles[role_id] do
      permissions = Permission.from_bitset(role.permissions)
      {:ok, permissions}
    else
      {:error, err} -> {:error, err}
      nil -> {:error, :role_not_found}
      v -> {:error, {:unknown_value, v}}
    end
  end
end
