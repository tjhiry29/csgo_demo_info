defmodule GameEventParser do
  def process_player_hurt_event({player_round_records, tmp_events}, event) do
    {user, user_index, id} = find_player(event, player_round_records)
    dmg_dealt = GameEvent.get_dmg_health(event)

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
          PlayerRoundRecord.update_attacker_damage_dealt(attacker, dmg_dealt, id)
      end

    player_round_records =
      player_round_records
      |> PlayerRoundRecord.replace_players([user_index, attacker_index], [user, attacker])

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
      |> PlayerRoundRecord.replace_players([user_index, attacker_index, assister_index], [
        user,
        attacker,
        assister
      ])

    {player_round_records, tmp_events}
  end

  def process_grenade_throw_event({player_round_records, tmp_events}, event) do
    {player, player_index, _} = find_player(event, player_round_records)

    grenade_throw = create_grenade_throw(event, player)

    player = %{player | grenade_throws: [grenade_throw | player.grenade_throws]}

    player_round_records =
      PlayerRoundRecord.replace_player(player_round_records, player_index, player)

    tmp_events = [grenade_throw | tmp_events]
    {player_round_records, tmp_events}
  end

  def process_grenade_hit_event({player_round_records, tmp_events}, event) do
    {_, _, user_id} = find_player(event, player_round_records)
    {attacker, attacker_index, attacker_id} = find_attacker(event, player_round_records)
    event_index = GameEvent.find_hegrenade_detonate(tmp_events, attacker_id)

    cond do
      event_index != nil ->
        hegrenade_detonate = Enum.at(tmp_events, event_index)

        hegrenade_throw =
          hegrenade_detonate.fields
          |> Map.get("hegrenade_throw")
          |> HegrenadeThrow.update_damage_dealt(user_id, event)

        hegrenade_detonate = %{
          hegrenade_detonate
          | fields: Map.put(hegrenade_detonate.fields, "hegrenade_throw", hegrenade_throw)
        }

        attacker = PlayerRoundRecord.replace_grenade_throw(attacker, hegrenade_throw)

        player_round_records =
          player_round_records
          |> PlayerRoundRecord.replace_player(attacker_index, attacker)

        tmp_events = List.replace_at(tmp_events, event_index, hegrenade_detonate)

        {player_round_records, tmp_events}

      true ->
        {player_round_records, tmp_events}
    end
  end

  def process_player_blind_event({player_round_records, tmp_events}, event) do
    {user, _, _} = find_player(event, player_round_records)
    {attacker, attacker_index, attacker_id} = find_attacker(event, player_round_records)
    event_index = GameEvent.find_flashbang_detonate(tmp_events, attacker_id, event)

    flashbang_detonate = Enum.at(tmp_events, event_index)

    flashbang_throw =
      flashbang_detonate.fields
      |> Map.get("flashbang_throw")
      |> FlashbangThrow.update_blind_information(user, event)

    flashbang_detonate = %{
      flashbang_detonate
      | fields: Map.put(flashbang_detonate.fields, "flashbang_throw", flashbang_throw)
    }

    attacker = PlayerRoundRecord.replace_grenade_throw(attacker, flashbang_throw)

    player_round_records =
      PlayerRoundRecord.replace_player(player_round_records, attacker_index, attacker)

    tmp_events = List.replace_at(tmp_events, event_index, flashbang_detonate)

    {player_round_records, tmp_events}
  end

  def process_hegrenade_detonate_event({player_round_records, tmp_events}, event) do
    {_, _, id} = GameEventParser.find_player(event, player_round_records)

    event_index =
      tmp_events
      |> Enum.find_index(fn e ->
        HegrenadeThrow.is_hegrenade_throw(e) && !e.detonated && e.player_id == id
      end)

    location = GameEvent.get_xyz_location(event)

    hegrenade_throw =
      tmp_events
      |> Enum.at(event_index)
      |> grenade_detonated(location)

    event = %{event | fields: Map.put(event.fields, "hegrenade_throw", hegrenade_throw)}
    tmp_events = GameEvent.update_events(tmp_events, event_index, event)

    {player_round_records, tmp_events}
  end

  def process_flashbang_detonate_event({player_round_records, tmp_events}, event) do
    {_, _, id} = GameEventParser.find_player(event, player_round_records)

    event_index =
      tmp_events
      |> Enum.find_index(fn e ->
        FlashbangThrow.is_flashbang_throw(e) && !e.detonated && e.player_id == id
      end)

    location = GameEvent.get_xyz_location(event)

    flashbang_throw =
      tmp_events
      |> Enum.at(event_index)
      |> grenade_detonated(location)

    event = %{event | fields: Map.put(event.fields, "flashbang_throw", flashbang_throw)}
    tmp_events = GameEvent.update_events(tmp_events, event_index, event)

    {player_round_records, tmp_events}
  end

  def grenade_detonated(grenade_throw, location) do
    grenade_throw
    |> Map.put(:detonated, true)
    |> Map.put(:location, location)
  end

  def find_attacker(event, player_round_records) do
    case GameEvent.get_attacker(event) do
      "0" ->
        {nil, nil, nil}

      _ ->
        find_player(event, player_round_records, "attacker")
    end
  end

  def find_assister(event, player_round_records) do
    case GameEvent.get_assister(event) do
      "0" ->
        {nil, nil, nil}

      _ ->
        find_player(event, player_round_records, "assister")
    end
  end

  def find_player(event, player_round_records, field \\ "userid") do
    {_, id} = GameEvent.process_player_field(event, field)
    user_index = Enum.find_index(player_round_records, fn p -> p.id == id end)
    {Enum.at(player_round_records, user_index || 11), user_index, id}
  end

  def create_kill(%GameEvent{type: "player_death"} = event, user, attacker, assister) do
    victim_position = GameEvent.get_position(event)
    attacker_position = GameEvent.get_attacker_position(event)
    {round, tick, headshot, weapon} = GameEvent.get_kill_info(event)
    assist = create_assist(event, user, assister)

    %Kill{
      attacker_name: attacker.name,
      victim_name: user.name,
      weapon: weapon,
      round: round,
      tick: tick,
      headshot: headshot,
      victim_position: victim_position,
      attacker_position: attacker_position,
      assist: assist
    }
  end

  def create_kill(_, _) do
    nil
  end

  def create_assist(nil, _, _), do: nil
  def create_assist(_, _, nil), do: nil

  def create_assist(%GameEvent{type: "player_death"} = event, victim, assister) do
    {round, tick, _, _} = GameEvent.get_kill_info(event)

    %Assist{
      victim_name: victim.name,
      assister_name: assister.name,
      round: round,
      tick: tick
    }
  end

  def create_assist(_, _), do: nil

  def create_player_round_records(players, round_num) do
    Enum.map(players, fn player_event ->
      {name, id} = GameEvent.process_player_field(player_event)

      team = Map.get(player_event.fields, "team")
      %PlayerRoundRecord{name: name, id: id, team: team, round: round_num}
    end)
  end

  def create_grenade_throw(event, player) do
    {tick, round, origin, facing} = GameEvent.get_grenade_throw_info(event)

    case GameEvent.get_weapon(event) do
      "weapon_incgrenade" ->
        %MolotovThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_molotov" ->
        %MolotovThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_flashbang" ->
        %FlashbangThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_hegrenade" ->
        %HegrenadeThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_smokegrenade" ->
        %SmokegrenadeThrow{
          player_name: player.name,
          player_id: player.id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      _ ->
        nil
    end
  end
end
