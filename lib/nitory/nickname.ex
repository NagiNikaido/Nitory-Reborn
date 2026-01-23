defmodule Nitory.Nickname do
  use Ecto.Schema

  schema "nickname" do
    field :user_id, :integer
    field :group_id, :integer
    field :nick, :string
  end

  def get_nick(user_id, group_id, default \\ "") do
    case Nitory.Repo.get_by(__MODULE__, %{user_id: user_id, group_id: group_id}) do
      %{nick: nick} -> nick
      nil -> default
    end
  end

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

  def rm_nick(user_id, group_id) do
    Nitory.Repo.transact(fn ->
      s = Nitory.Repo.get_by(__MODULE__, %{user_id: user_id, group_id: group_id})

      if s != nil do
        Nitory.Repo.delete(s)
      end
    end)
  end
end
