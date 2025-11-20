defmodule SamplePhoenix.TrainDemo do
  @moduledoc """
  Demo script for querying trains data from DuckLake.

  Run this with: `mix run -e "SamplePhoenix.TrainDemo.run()"`
  """

  alias SamplePhoenix.{DuckLakeRepo, Train}
  import Ecto.Query

  def run do
    IO.puts("\n=== DuckLake Train Queries Demo ===\n")

    # Insert sample data first
    insert_sample_data()

    # Example 1: Get all trains
    example_all_trains()

    # Example 2: Query by station
    example_by_station()

    # Example 3: Find delayed trains
    example_delayed_trains()

    # Example 4: Find canceled trains
    example_canceled_trains()

    # Example 5: Raw SQL query
    example_raw_sql()

    # Example 6: Analytics - Average delays by station
    example_analytics_delays()

    # Example 7: Analytics - Platform changes
    example_platform_changes()

    # Example 8: Complex query with joins
    example_complex_query()

    IO.puts("\n=== Demo Complete ===\n")
  end

  defp insert_sample_data do
    IO.puts("📝 Inserting sample train data...\n")

    # Clear existing data
    DuckLakeRepo.delete_all(Train)

    sample_trains = [
      %{
        service_number: 1234,
        station_code: "AMS",
        service_type_code: "IC",
        company_code: 100,
        service_type_description: "Intercity",
        company_name: "NS",
        service_parts: "AMS-RTD",
        stop_type_code: "STOP",
        stop_type_description: "Regular stop",
        departure_time: ~T[10:30:00],
        arrival_time: ~T[10:28:00],
        arrival_delay_minutes: 5,
        departure_delay_minutes: 3,
        canceled: false,
        route_text: "Amsterdam - Rotterdam",
        platform: "5a",
        platform_changed: true
      },
      %{
        service_number: 1234,
        station_code: "RTD",
        service_type_code: "IC",
        company_code: 100,
        service_type_description: "Intercity",
        company_name: "NS",
        service_parts: "AMS-RTD",
        stop_type_code: "STOP",
        stop_type_description: "Regular stop",
        departure_time: ~T[11:15:00],
        arrival_time: ~T[11:13:00],
        arrival_delay_minutes: 5,
        departure_delay_minutes: 5,
        canceled: false,
        route_text: "Amsterdam - Rotterdam",
        platform: "7",
        platform_changed: false
      },
      %{
        service_number: 5678,
        station_code: "AMS",
        service_type_code: "SPR",
        company_code: 100,
        service_type_description: "Sprinter",
        company_name: "NS",
        service_parts: "AMS-UTR",
        stop_type_code: "STOP",
        stop_type_description: "Regular stop",
        departure_time: ~T[14:00:00],
        arrival_time: ~T[13:58:00],
        arrival_delay_minutes: 0,
        departure_delay_minutes: 0,
        canceled: false,
        route_text: "Amsterdam - Utrecht",
        platform: "3",
        platform_changed: false
      },
      %{
        service_number: 9999,
        station_code: "UTR",
        service_type_code: "IC",
        company_code: 100,
        service_type_description: "Intercity",
        company_name: "NS",
        service_parts: "UTR-EHV",
        stop_type_code: "STOP",
        stop_type_description: "Regular stop",
        departure_time: ~T[16:30:00],
        arrival_time: ~T[16:25:00],
        arrival_delay_minutes: 15,
        departure_delay_minutes: 20,
        canceled: false,
        route_text: "Utrecht - Eindhoven",
        platform: "12b",
        platform_changed: true
      },
      %{
        service_number: 7777,
        station_code: "AMS",
        service_type_code: "IC",
        company_code: 100,
        service_type_description: "Intercity",
        company_name: "NS",
        service_parts: "AMS-GRN",
        stop_type_code: "STOP",
        stop_type_description: "Regular stop",
        departure_time: ~T[18:00:00],
        arrival_time: nil,
        arrival_delay_minutes: 0,
        departure_delay_minutes: 0,
        canceled: true,
        route_text: "Amsterdam - Groningen",
        platform: "8",
        platform_changed: false
      }
    ]

    Enum.each(sample_trains, fn train_data ->
      %Train{}
      |> Train.changeset(train_data)
      |> DuckLakeRepo.insert!()
    end)

    IO.puts("✅ Inserted #{length(sample_trains)} trains\n")
  end

  defp example_all_trains do
    IO.puts("1️⃣ Get all trains:")
    IO.puts("   DuckLakeRepo.all(Train)\n")

    trains = DuckLakeRepo.all(Train)
    IO.puts("   Found #{length(trains)} trains")

    Enum.each(trains, fn train ->
      IO.puts("   - Service #{train.service_number} at #{train.station_code}")
    end)

    IO.puts("")
  end

  defp example_by_station do
    IO.puts("2️⃣ Get trains by station:")
    IO.puts("   DuckLakeRepo.all(Train.by_station(\"AMS\"))\n")

    trains = DuckLakeRepo.all(Train.by_station("AMS"))
    IO.puts("   Found #{length(trains)} trains at Amsterdam")

    Enum.each(trains, fn train ->
      IO.puts("   - Service #{train.service_number}: #{train.route_text}")
    end)

    IO.puts("")
  end

  defp example_delayed_trains do
    IO.puts("3️⃣ Find delayed trains:")
    IO.puts("   DuckLakeRepo.all(Train.delayed())\n")

    trains = DuckLakeRepo.all(Train.delayed())
    IO.puts("   Found #{length(trains)} delayed trains")

    Enum.each(trains, fn train ->
      IO.puts(
        "   - Service #{train.service_number} at #{train.station_code}: +#{train.departure_delay_minutes} min"
      )
    end)

    IO.puts("")
  end

  defp example_canceled_trains do
    IO.puts("4️⃣ Find canceled trains:")
    IO.puts("   DuckLakeRepo.all(Train.canceled())\n")

    trains = DuckLakeRepo.all(Train.canceled())
    IO.puts("   Found #{length(trains)} canceled trains")

    Enum.each(trains, fn train ->
      IO.puts("   - Service #{train.service_number}: #{train.route_text}")
    end)

    IO.puts("")
  end

  defp example_raw_sql do
    IO.puts("5️⃣ Raw SQL query:")

    sql = """
    SELECT station_code, COUNT(*) as train_count
    FROM trains
    GROUP BY station_code
    ORDER BY train_count DESC
    """

    IO.puts("   DuckLakeRepo.query!(\"#{String.replace(sql, "\n", " ")}\")\n")

    result = DuckLakeRepo.query!(sql)
    IO.puts("   Columns: #{inspect(result.columns)}")
    IO.puts("   Rows:")

    Enum.each(result.rows, fn [station, count] ->
      IO.puts("   - #{station}: #{count} trains")
    end)

    IO.puts("")
  end

  defp example_analytics_delays do
    IO.puts("6️⃣ Analytics: Average delays by station:")
    IO.puts("   DuckLakeRepo.all(Train.average_delays_by_station())\n")

    stats = DuckLakeRepo.all(Train.average_delays_by_station())
    IO.puts("   Station delay statistics:")

    Enum.each(stats, fn stat ->
      avg_arr = if stat.avg_arrival_delay, do: Float.round(stat.avg_arrival_delay, 1), else: 0
      avg_dep = if stat.avg_departure_delay, do: Float.round(stat.avg_departure_delay, 1), else: 0

      IO.puts(
        "   - #{stat.station_code}: Avg arrival delay: #{avg_arr} min, Avg departure delay: #{avg_dep} min (#{stat.total_trains} trains)"
      )
    end)

    IO.puts("")
  end

  defp example_platform_changes do
    IO.puts("7️⃣ Analytics: Platform change statistics:")
    IO.puts("   DuckLakeRepo.all(Train.platform_change_stats())\n")

    stats = DuckLakeRepo.all(Train.platform_change_stats())
    IO.puts("   Platform change statistics:")

    Enum.each(stats, fn stat ->
      change_pct = if stat.change_percentage, do: Float.round(stat.change_percentage, 1), else: 0

      IO.puts(
        "   - #{stat.station_code}: #{stat.platform_changes}/#{stat.total_trains} changes (#{change_pct}%)"
      )
    end)

    IO.puts("")
  end

  defp example_complex_query do
    IO.puts("8️⃣ Complex query: Trains with significant delays:")

    IO.puts("""
       query = from t in Train,
         where: t.departure_delay_minutes > 5,
         select: %{
           service: t.service_number,
           station: t.station_code,
           delay: t.departure_delay_minutes,
           route: t.route_text
         },
         order_by: [desc: t.departure_delay_minutes]

       DuckLakeRepo.all(query)

    """)

    query =
      from(t in Train,
        where: t.departure_delay_minutes > 5,
        select: %{
          service: t.service_number,
          station: t.station_code,
          delay: t.departure_delay_minutes,
          route: t.route_text
        },
        order_by: [desc: t.departure_delay_minutes]
      )

    results = DuckLakeRepo.all(query)
    IO.puts("   Found #{length(results)} trains with delays > 5 minutes:")

    Enum.each(results, fn result ->
      IO.puts(
        "   - Service #{result.service} at #{result.station}: +#{result.delay} min (#{result.route})"
      )
    end)

    IO.puts("")
  end
end
