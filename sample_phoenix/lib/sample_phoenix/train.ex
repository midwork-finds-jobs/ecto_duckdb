defmodule SamplePhoenix.Train do
  @moduledoc """
  Schema for train data stored in DuckLake.

  This uses the DuckLakeRepo which is optimized for analytical queries
  on time-series data.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "trains" do
    field :service_number, :integer
    field :station_code, :string
    field :service_type_code, :string
    field :company_code, :integer
    field :service_type_description, :string
    field :company_name, :string
    field :service_parts, :string
    field :stop_type_code, :string
    field :stop_type_description, :string
    field :departure_time, :time
    field :arrival_time, :time
    field :arrival_delay_minutes, :integer
    field :departure_delay_minutes, :integer
    field :canceled, :boolean
    field :route_text, :string
    field :platform, :string
    field :platform_changed, :boolean

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(train, attrs) do
    train
    |> cast(attrs, [
      :service_number,
      :station_code,
      :service_type_code,
      :company_code,
      :service_type_description,
      :company_name,
      :service_parts,
      :stop_type_code,
      :stop_type_description,
      :departure_time,
      :arrival_time,
      :arrival_delay_minutes,
      :departure_delay_minutes,
      :canceled,
      :route_text,
      :platform,
      :platform_changed
    ])
    |> validate_required([:service_number, :station_code])
  end

  @doc """
  Get all trains for a specific station.
  """
  def by_station(station_code) do
    from t in __MODULE__,
      where: t.station_code == ^station_code,
      order_by: [desc: t.departure_time]
  end

  @doc """
  Get delayed trains (arrival or departure delay > 0).
  """
  def delayed do
    from t in __MODULE__,
      where: t.arrival_delay_minutes > 0 or t.departure_delay_minutes > 0,
      order_by: [desc: t.departure_delay_minutes]
  end

  @doc """
  Get canceled trains.
  """
  def canceled do
    from t in __MODULE__,
      where: t.canceled == true
  end

  @doc """
  Get trains by service number.
  """
  def by_service_number(service_number) do
    from t in __MODULE__,
      where: t.service_number == ^service_number,
      order_by: [asc: t.departure_time]
  end

  @doc """
  Get trains departing within a time range.
  """
  def departing_between(start_time, end_time) do
    from t in __MODULE__,
      where: t.departure_time >= ^start_time and t.departure_time <= ^end_time,
      order_by: [asc: t.departure_time]
  end

  @doc """
  Analytics query: Get average delays by station.
  """
  def average_delays_by_station do
    from t in __MODULE__,
      group_by: t.station_code,
      select: %{
        station_code: t.station_code,
        avg_arrival_delay: avg(t.arrival_delay_minutes),
        avg_departure_delay: avg(t.departure_delay_minutes),
        total_trains: count(t.id)
      },
      order_by: [desc: avg(t.departure_delay_minutes)]
  end

  @doc """
  Analytics query: Get platform change statistics.
  """
  def platform_change_stats do
    from t in __MODULE__,
      where: not is_nil(t.platform_changed),
      group_by: t.station_code,
      select: %{
        station_code: t.station_code,
        total_trains: count(t.id),
        platform_changes: fragment("CAST(SUM(CASE WHEN ? THEN 1 ELSE 0 END) AS INTEGER)", t.platform_changed),
        change_percentage: fragment("(SUM(CASE WHEN ? THEN 1 ELSE 0 END) * 100.0 / COUNT(*))", t.platform_changed)
      },
      order_by: [desc: fragment("(SUM(CASE WHEN ? THEN 1 ELSE 0 END) * 100.0 / COUNT(*))", t.platform_changed)]
  end
end
