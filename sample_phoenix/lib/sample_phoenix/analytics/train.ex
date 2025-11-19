defmodule SamplePhoenix.Analytics.Train do
  @moduledoc """
  Train service schema for Dutch railway data.

  Stores train service information from the NS (Nederlandse Spoorwegen) dataset.
  This data is stored in DuckLake format for efficient analytics and time-series queries.
  """

  use Ecto.Schema
  import Ecto.Changeset

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
end
