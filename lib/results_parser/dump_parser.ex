defmodule ResultsParser.DumpParser do
  alias GameEvent, as: GameEvent

  @num_server_info_lines 19
  @tick_interval_key "tick_interval:"
  @filter_events [
    "round_announce_match_point",
    "decoy_started",
    "player_spawn",
    "announce_phase_end",
    "round_time_warning",
    "round_announce_last_round_half",
    "cs_round_final_beep",
    "cs_pre_restart",
    "cs_win_panel_round",
    "player_team",
    "cs_win_panel_round",
    "decoy_detonate",
    "round_freeze_end",
    "round_poststart",
    "hltv_fixed",
    "round_officially_ended",
    "round_announce_match_start",
    "round_end"
  ]

  def parse_game_events(file_name) do
    if File.exists?("results/#{file_name}.dump") do
      # parse dump
      stream = File.stream!("results/#{file_name}.dump")
      {server_info, dump_stream} = Enum.split(stream, @num_server_info_lines)
      tick_rate = get_tick_rate(server_info)
      tick_rate = round(1 / tick_rate)

      result =
        dump_stream
        |> Enum.map(&String.trim_trailing(&1, "\n"))
        |> Enum.map_reduce(nil, &parse_dump_line(&1, &2))

      {list, _} = result
      list = list |> Enum.filter(fn x -> x != nil end)
      events_map =
        list
        |> Enum.filter(fn x ->
          !Enum.member?(@filter_events, x.type)
        end)
        |> Enum.sort(fn e1, e2 ->
          e1.fields |> Map.get("round_num") |> String.to_integer() <
            e2.fields |> Map.get("round_num") |> String.to_integer()
        end)
        |> Enum.sort(fn e1, e2 ->
          e1.fields |> Map.get("tick") |> String.to_integer() <
            e2.fields |> Map.get("tick") |> String.to_integer()
        end)
        |> Enum.group_by(fn x -> Map.get(x.fields, "round_num") |> String.to_integer() end)
        |> Enum.reduce([], fn {round_num, events}, acc -> process_round(events, acc) end)

      IO.inspect(events_map)
    else
      IO.puts("No such file results/#{file_name}.dump, please check the directory 
                or ensure the demo dump goes through as expected")
    end
  end

  defp process_round(events, acc) do
    events
  end

  defp get_tick_rate(server_info) do
    tick_rate_chunk =
      server_info
      |> Enum.filter(fn e ->
        e |> String.split(" ") |> Enum.at(0) == @tick_interval_key
      end)

    tick_rate_chunk
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)
    |> String.trim_trailing("\n")
    |> String.to_float()
  end

  defp parse_dump_line(line, acc) do
    cond do
      String.contains?(line, "{") ->
        event_type = line |> String.split(" ") |> Enum.at(0)
        acc = %GameEvent{type: event_type}
        {nil, acc}

      String.contains?(line, "}") ->
        {acc, nil}

      acc != nil ->
        fields =
          line |> String.trim_trailing("\n") |> String.split(": ")
          |> Enum.map(fn str ->
            str |> String.trim_trailing(" ") |> String.trim_leading(" ")
          end)

        fields =
          if Map.has_key?(acc.fields, Enum.at(fields, 0)) do
            new_key = Enum.at(fields, 0) <> "_2"
            fields = List.delete_at(fields, 0)
            List.insert_at(fields, 0, new_key)
          else
            fields
          end

        new_fields = Map.put(acc.fields, Enum.at(fields, 0), Enum.at(fields, 1))
        {nil, %{acc | fields: new_fields}}

      true ->
        {nil, acc}
    end
  end
end
