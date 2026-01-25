defmodule Nitory.Repo.Migrations.CreateKhst do
  use Ecto.Migration

  def change do
    create table(:khst_picture) do
      add :hash_sum, :string, null: false
      add :path, :string, null: false
    end

    create table(:khst_keyword2picture) do
      add :keyword, :string, null: false
      add :group_id, :integer
      add :tag, :string
      add :picture_id,
          references(:khst_picture, on_delete: :delete_all),
          null: false
    end

    create table(:khst_history) do
      add :message_id, :integer
      add :keyword, :string, null: false
      add :group_id, :integer
      add :picture_id,
          references(:khst_picture, on_delete: :delete_all),
          null: false
    end
  end
end
