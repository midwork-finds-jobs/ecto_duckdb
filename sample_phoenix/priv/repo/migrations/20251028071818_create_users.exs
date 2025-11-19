defmodule SamplePhoenix.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :email, :string
      add :age, :integer

      timestamps(type: :naive_datetime)
    end

    create unique_index(:users, [:email])
  end
end
