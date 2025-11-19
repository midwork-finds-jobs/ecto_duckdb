defmodule SamplePhoenix.Repo.Migrations.TestNativeDatetimeTypes do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :name, :string
      add :event_date, :date
      add :event_time, :time
      add :scheduled_at, :naive_datetime
      add :published_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
