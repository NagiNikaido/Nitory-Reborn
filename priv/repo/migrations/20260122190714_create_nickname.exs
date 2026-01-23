defmodule Nitory.Repo.Migrations.CreateNickname do
  use Ecto.Migration

  def change do
    create table(:nickname) do
      add :user_id, :integer
      add :group_id, :integer
      add :nick, :string
    end
  end
end
