defmodule Nitory.Nickname do
  @moduledoc """
  Ecto schema for per-user, per-group nickname persistence.

  Stores a custom display name for a user within a specific group.
  Provides `get_nick/3`, `set_nick/3`, and `rm_nick/2` for
  reading, upserting, and deleting nickname records.

  Backed by the `nickname` table in the SQLite3 database.
  """

  use Ecto.Schema

  schema "nickname" do
    field :user_id, :integer
    field :group_id, :integer
    field :nick, :string
  end

  @doc """
  Looks up a user's nickname in a group.

  Returns the stored nickname, or `default` if none is set.
  """
  def get_nick(user_id, group_id, default \\ "") do
    case Nitory.Repo.get_by(__MODULE__, %{user_id: user_id, group_id: group_id}) do
      %{nick: nick} -> nick
      nil -> default
    end
  end

  @doc """
  Stores or updates a user's nickname in a group.

  Uses an upsert (`on_conflict: :replace_all`) so repeated calls
  overwrite the previous value.
  """
  def set_nick(user_id, group_id, nick) do
    Nitory.Repo.transact(fn ->
      Nitory.Repo.get_by(__MODULE__, %{user_id: user_id, group_id: group_id})
      |> (&if(&1 == nil, do: %__MODULE__{}, else: &1)).()
      |> Ecto.Changeset.cast(%{user_id: user_id, group_id: group_id, nick: nick}, [
        :user_id,
        :group_id,
        :nick
      ])
      |> Nitory.Repo.insert(on_conflict: :replace_all)
    end)
  end

  @doc """
  Removes a nickname record for the given user and group.

  Returns nil if no record existed.
  """
  def rm_nick(user_id, group_id) do
    Nitory.Repo.transact(fn ->
      s = Nitory.Repo.get_by(__MODULE__, %{user_id: user_id, group_id: group_id})

      if s != nil do
        Nitory.Repo.delete(s)
      end
    end)
  end
end
