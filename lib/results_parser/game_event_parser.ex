defmodule ResultsParser.GameEventParser do
  def process_player_hurt_event({player_round_records, tmp_events}, event) do
    {user, user_index, id} = find_player(event, player_round_records)
    dmg_dealt = DemoInfoGo.GameEvent.get_dmg_health(event)

    if user == nil do
      IO.inspect(player_round_records)
    end

    health = user.health - dmg_dealt
    new_health = if health < 0, do: 0, else: health

    dmg_dealt = if new_health == 0, do: user.health, else: dmg_dealt
    user = %{user | health: new_health}

    {attacker, attacker_index, _} = find_attacker(event, player_round_records)

    attacker =
      cond do
        attacker && attacker.team == user.team ->
          attacker

        true ->
          DemoInfoGo.PlayerRoundRecord.update_attacker_damage_dealt(attacker, dmg_dealt, id)
      end

    player_round_records =
      player_round_records
      |> DemoInfoGo.PlayerRoundRecord.replace_players([user_index, attacker_index], [
        user,
        attacker
      ])

    {player_round_records, tmp_events}
  end

  def process_player_death_event({player_round_records, tmp_events}, event) do
    {user, user_index, _} = find_player(event, player_round_records)
    {attacker, attacker_index, _} = find_attacker(event, player_round_records)
    {assister, assister_index, _} = find_assister(event, player_round_records)

    assist = create_assist(event, user, assister)
    kill = create_kill(event, user, attacker, assister)

    user = %{user | death: kill, dead: true}
    kills = [kill | attacker.kills]
    attacker = %{attacker | kills: kills}

    assister =
      if assister != nil do
        assists = [assist | assister.assists]
        %{assister | assists: assists}
      end

    player_round_records =
      player_round_records
      |> DemoInfoGo.PlayerRoundRecord.replace_players(
        [user_index, attacker_index, assister_index],
        [
          user,
          attacker,
          assister
        ]
      )

    {player_round_records, tmp_events}
  end

  def process_grenade_throw_event({player_round_records, tmp_events}, event) do
    {player, player_index, _} = find_player(event, player_round_records)

    grenade_throw = create_grenade_throw(event, player)

    player = %{player | grenade_throws: [grenade_throw | player.grenade_throws]}

    player_round_records =
      DemoInfoGo.PlayerRoundRecord.replace_player(player_round_records, player_index, player)

    tmp_events = [grenade_throw | tmp_events]
    {player_round_records, tmp_events}
  end

  def process_grenade_hit_event({player_round_records, tmp_events}, event) do
    {_, _, user_id} = find_player(event, player_round_records)
    {attacker, attacker_index, attacker_id} = find_attacker(event, player_round_records)
    event_index = DemoInfoGo.GameEvent.find_hegrenade_detonate(tmp_events, attacker_id)

    cond do
      event_index != nil ->
        hegrenade_detonate = Enum.at(tmp_events, event_index)

        hegrenade_throw =
          hegrenade_detonate.fields
          |> Map.get("hegrenade_throw")
          |> DemoInfoGo.HegrenadeThrow.update_damage_dealt(user_id, event)

        hegrenade_detonate = %{
          hegrenade_detonate
          | fields: Map.put(hegrenade_detonate.fields, "hegrenade_throw", hegrenade_throw)
        }

        attacker = DemoInfoGo.PlayerRoundRecord.replace_grenade_throw(attacker, hegrenade_throw)

        player_round_records =
          player_round_records
          |> DemoInfoGo.PlayerRoundRecord.replace_player(attacker_index, attacker)

        tmp_events = List.replace_at(tmp_events, event_index, hegrenade_detonate)

        {player_round_records, tmp_events}

      true ->
        {player_round_records, tmp_events}
    end
  end

  def process_inferno_hit_event({player_round_records, tmp_events}, event) do
    {_, _, user_id} = find_player(event, player_round_records)
    {attacker, attacker_index, attacker_id} = find_attacker(event, player_round_records)
    event_index = DemoInfoGo.GameEvent.find_inferno_startburn(tmp_events, attacker_id)

    cond do
      event_index != nil ->
        inferno_startburn = Enum.at(tmp_events, event_index)

        molotov_throw =
          inferno_startburn.fields
          |> Map.get("molotov_throw")
          |> DemoInfoGo.MolotovThrow.update_damage_dealt(user_id, event)

        inferno_startburn = %{
          inferno_startburn
          | fields: Map.put(inferno_startburn.fields, "molotov_throw", molotov_throw)
        }

        attacker = DemoInfoGo.PlayerRoundRecord.replace_grenade_throw(attacker, molotov_throw)

        player_round_records =
          player_round_records
          |> DemoInfoGo.PlayerRoundRecord.replace_player(attacker_index, attacker)

        tmp_events = List.replace_at(tmp_events, event_index, inferno_startburn)

        {player_round_records, tmp_events}

      true ->
        {player_round_records, tmp_events}
    end
  end

  def process_player_blind_event({player_round_records, tmp_events}, event) do
    {user, _, _} = find_player(event, player_round_records)
    {attacker, attacker_index, attacker_id} = find_attacker(event, player_round_records)
    event_index = DemoInfoGo.GameEvent.find_flashbang_detonate(tmp_events, attacker_id, event)

    flashbang_detonate = Enum.at(tmp_events, event_index)

    flashbang_throw =
      flashbang_detonate.fields
      |> Map.get("flashbang_throw")
      |> DemoInfoGo.FlashbangThrow.update_blind_information(user, event)

    flashbang_detonate = %{
      flashbang_detonate
      | fields: Map.put(flashbang_detonate.fields, "flashbang_throw", flashbang_throw)
    }

    attacker = DemoInfoGo.PlayerRoundRecord.replace_grenade_throw(attacker, flashbang_throw)

    player_round_records =
      DemoInfoGo.PlayerRoundRecord.replace_player(player_round_records, attacker_index, attacker)

    tmp_events = List.replace_at(tmp_events, event_index, flashbang_detonate)

    {player_round_records, tmp_events}
  end

  def process_hegrenade_detonate_event({player_round_records, tmp_events}, event) do
    {_, _, id} = find_player(event, player_round_records)

    event_index =
      tmp_events
      |> Enum.find_index(fn e ->
        DemoInfoGo.HegrenadeThrow.is_hegrenade_throw(e) && !e.detonated && e.player_id == id
      end)

    location = DemoInfoGo.GameEvent.get_xyz_location(event)

    case event_index do
      nil ->
        {player_round_records, tmp_events}

      _ ->
        hegrenade_throw =
          tmp_events
          |> Enum.at(event_index)
          |> grenade_detonated(location)

        event = %{event | fields: Map.put(event.fields, "hegrenade_throw", hegrenade_throw)}
        tmp_events = DemoInfoGo.GameEvent.update_events(tmp_events, event_index, event)

        {player_round_records, tmp_events}
    end
  end

  def process_flashbang_detonate_event({player_round_records, tmp_events}, event) do
    {_, _, id} = find_player(event, player_round_records)

    event_index =
      tmp_events
      |> Enum.find_index(fn e ->
        DemoInfoGo.FlashbangThrow.is_flashbang_throw(e) && !e.detonated && e.player_id == id
      end)

    location = DemoInfoGo.GameEvent.get_xyz_location(event)

    flashbang_throw =
      tmp_events
      |> Enum.at(event_index)
      |> grenade_detonated(location)

    event = %{event | fields: Map.put(event.fields, "flashbang_throw", flashbang_throw)}
    tmp_events = DemoInfoGo.GameEvent.update_events(tmp_events, event_index, event)

    {player_round_records, tmp_events}
  end

  def process_smokegrenade_detonate_event({player_round_records, tmp_events}, event) do
    {user, user_index, id} = find_player(event, player_round_records)

    event_index =
      tmp_events
      |> Enum.find_index(fn e ->
        DemoInfoGo.SmokegrenadeThrow.is_smokegrenade_throw(e) && !e.detonated && e.player_id == id
      end)

    location = DemoInfoGo.GameEvent.get_xyz_location(event)

    case event_index do
      nil ->
        {player_round_records, tmp_events}

      _ ->
        smokegrenade_throw =
          tmp_events
          |> Enum.at(event_index)
          |> grenade_detonated(location)

        user = DemoInfoGo.PlayerRoundRecord.replace_grenade_throw(user, smokegrenade_throw)

        player_round_records =
          DemoInfoGo.PlayerRoundRecord.replace_player(player_round_records, user_index, user)

        {player_round_records, tmp_events}
    end
  end

  def process_inferno_startburn_event({player_round_records, tmp_events}, event) do
    event_index =
      tmp_events
      |> Enum.find_index(fn e ->
        DemoInfoGo.MolotovThrow.is_molotov_throw(e) && !e.detonated && e.entityid == nil
      end)

    location = DemoInfoGo.GameEvent.get_xyz_location(event)

    molotov_throw =
      tmp_events
      |> Enum.at(event_index)
      |> grenade_detonated(location)
      |> Map.put(:entityid, DemoInfoGo.GameEvent.get_entityid(event))

    user_index =
      player_round_records
      |> Enum.find_index(fn p ->
        p.id == molotov_throw.player_id
      end)

    user =
      player_round_records
      |> Enum.at(user_index)
      |> DemoInfoGo.PlayerRoundRecord.replace_grenade_throw(molotov_throw)

    player_round_records =
      DemoInfoGo.PlayerRoundRecord.replace_player(player_round_records, user_index, user)

    event = %{event | fields: Map.put(event.fields, "molotov_throw", molotov_throw)}
    tmp_events = DemoInfoGo.GameEvent.update_events(tmp_events, event_index, event)

    {player_round_records, tmp_events}
  end

  def process_inferno_expire_event({player_round_records, tmp_events}, event) do
    event_index =
      tmp_events
      |> Enum.find_index(fn e ->
        DemoInfoGo.GameEvent.is_game_event(e) && e.type == "inferno_startburn" &&
          Map.get(e.fields, "molotov_throw").detonated &&
          !Map.get(e.fields, "molotov_throw").expired &&
          DemoInfoGo.GameEvent.get_entityid(e) == DemoInfoGo.GameEvent.get_entityid(event)
      end)

    molotov_throw =
      tmp_events
      |> Enum.at(event_index)
      |> Map.get(:fields)
      |> Map.get("molotov_throw")
      |> Map.put(:expired, true)

    user_index =
      player_round_records
      |> Enum.find_index(fn p ->
        p.id == molotov_throw.player_id
      end)

    user =
      player_round_records
      |> Enum.at(user_index)
      |> DemoInfoGo.PlayerRoundRecord.replace_grenade_throw(molotov_throw)

    player_round_records =
      DemoInfoGo.PlayerRoundRecord.replace_player(player_round_records, user_index, user)

    event = %{event | fields: Map.put(event.fields, "molotov_throw", molotov_throw)}
    tmp_events = DemoInfoGo.GameEvent.update_events(tmp_events, event_index, event)

    {player_round_records, tmp_events}
  end

  def grenade_detonated(grenade_throw, location) do
    grenade_throw
    |> Map.put(:detonated, true)
    |> Map.put(:location, location)
  end

  def find_attacker(event, player_round_records) do
    case DemoInfoGo.GameEvent.get_attacker(event) do
      "0" ->
        {nil, nil, nil}

      _ ->
        find_player(event, player_round_records, "attacker")
    end
  end

  def find_assister(event, player_round_records) do
    case DemoInfoGo.GameEvent.get_assister(event) do
      "0" ->
        {nil, nil, nil}

      _ ->
        find_player(event, player_round_records, "assister")
    end
  end

  def find_player(event, player_round_records, field \\ "userid") do
    {_, id} = DemoInfoGo.GameEvent.process_player_field(event, field)
    user_index = Enum.find_index(player_round_records, fn p -> p.id == id end)
    {Enum.at(player_round_records, user_index || 11), user_index, id}
  end

  def create_kill(%DemoInfoGo.GameEvent{type: "player_death"} = event, user, attacker, assister) do
    victim_position = DemoInfoGo.GameEvent.get_position(event)
    attacker_position = DemoInfoGo.GameEvent.get_attacker_position(event)
    {round, tick, headshot, weapon} = DemoInfoGo.GameEvent.get_kill_info(event)
    assist = create_assist(event, user, assister)

    %DemoInfoGo.Kill{
      attacker_name: attacker.name,
      attacker_id: attacker.id,
      victim_name: user.name,
      victim_id: user.id,
      weapon: weapon,
      round: round,
      tick: tick,
      headshot: headshot,
      victim_position: victim_position,
      attacker_position: attacker_position,
      assist: assist,
      time_left_in_round: DemoInfoGo.GameEvent.get_time_left_in_round(event),
      time_elapsed: DemoInfoGo.GameEvent.get_time_elapsed(event)
    }
  end

  def create_kill(_, _) do
    nil
  end

  def create_assist(nil, _, _), do: nil
  def create_assist(_, _, nil), do: nil

  def create_assist(%DemoInfoGo.GameEvent{type: "player_death"} = event, victim, assister) do
    {round, tick, _, _} = DemoInfoGo.GameEvent.get_kill_info(event)

    %DemoInfoGo.Assist{
      victim_name: victim.name,
      victim_id: victim.id,
      assister_name: assister.name,
      assister_id: assister.id,
      round: round,
      tick: tick,
      time_left_in_round: DemoInfoGo.GameEvent.get_time_left_in_round(event),
      time_elapsed: DemoInfoGo.GameEvent.get_time_elapsed(event)
    }
  end

  def create_assist(_, _, _), do: nil

  def create_player_round_records(players, round_num) do
    Enum.map(players, fn player_event ->
      {name, id} = DemoInfoGo.GameEvent.process_player_field(player_event)

      team = DemoInfoGo.GameEvent.get_team(player_event)
      teamnum = DemoInfoGo.GameEvent.get_teamnum(player_event)

      %DemoInfoGo.PlayerRoundRecord{
        name: name,
        id: id,
        team: team,
        round: round_num,
        teamnum: teamnum
      }
    end)
  end

  def create_grenade_throw(event, player) do
    {tick, round, origin, facing} = DemoInfoGo.GameEvent.get_grenade_throw_info(event)

    case DemoInfoGo.GameEvent.get_weapon(event) do
      "weapon_incgrenade" ->
        %DemoInfoGo.MolotovThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing,
          time_left_in_round: DemoInfoGo.GameEvent.get_time_left_in_round(event),
          time_elapsed: DemoInfoGo.GameEvent.get_time_elapsed(event)
        }

      "weapon_molotov" ->
        %DemoInfoGo.MolotovThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing,
          time_left_in_round: DemoInfoGo.GameEvent.get_time_left_in_round(event),
          time_elapsed: DemoInfoGo.GameEvent.get_time_elapsed(event)
        }

      "weapon_flashbang" ->
        %DemoInfoGo.FlashbangThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing,
          time_left_in_round: DemoInfoGo.GameEvent.get_time_left_in_round(event),
          time_elapsed: DemoInfoGo.GameEvent.get_time_elapsed(event)
        }

      "weapon_hegrenade" ->
        %DemoInfoGo.HegrenadeThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing,
          time_left_in_round: DemoInfoGo.GameEvent.get_time_left_in_round(event),
          time_elapsed: DemoInfoGo.GameEvent.get_time_elapsed(event)
        }

      "weapon_smokegrenade" ->
        %DemoInfoGo.SmokegrenadeThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing,
          time_left_in_round: DemoInfoGo.GameEvent.get_time_left_in_round(event),
          time_elapsed: DemoInfoGo.GameEvent.get_time_elapsed(event)
        }

      _ ->
        nil
    end
  end
end
