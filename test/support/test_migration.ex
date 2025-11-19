defmodule EctoDuckdbex.TestMigration do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :email, :string
      add :age, :integer
      timestamps()
    end

    create unique_index(:users, [:email])

    create table(:posts) do
      add :title, :string
      add :body, :text
      add :published, :boolean, default: false
      add :user_id, references(:users, on_delete: :nothing)
      timestamps()
    end
  end
end
