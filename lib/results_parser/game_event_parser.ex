defmodule GameEventParser do
  def process_player_hurt_event({player_round_records, tmp_events}, event) do
    {user, user_index, id} = find_player(event, player_round_records)
    dmg_dealt = event.fields |> Map.get("dmg_health") |> String.to_integer()

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
    user = %{user | dead: true}
    victim_position = GameEvent.get_position(event)
    {round, tick, headshot, weapon} = GameEvent.get_kill_info(event)

    {attacker, attacker_index, _} = find_attacker(event, player_round_records)
    attacker_position = GameEvent.get_position(event, 2)

    {assister, assister_index, _} = find_assister(event, player_round_records)

    assist = create_assist(assister, user.name, round, tick)

    kill = %Kill{
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

    user = %{user | death: kill}
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

  def process_grenade_throw_event(event) do
    [player_name, player_id] = GameEvent.process_player_field(event)
    {tick, round, origin, facing} = GameEvent.get_grenade_throw_info(event)

    case GameEvent.get_weapon(event) do
      "weapon_incgrenade" ->
        %MolotovThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_molotov" ->
        %MolotovThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_flashbang" ->
        %FlashbangThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_hegrenade" ->
        %HegrenadeThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_smokegrenade" ->
        %SmokegrenadeThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      _ ->
        nil
    end
  end

  def process_grenade_hit_event(event, player_round_records, tmp_events) do
    {user, _, user_id} = find_player(event, player_round_records)

    {attacker, attacker_index, attacker_id} = find_player(event, player_round_records, "attacker")

    event_index =
      Enum.find_index(tmp_events, fn e ->
        cond do
          GameEvent.is_game_event(e) && e.type == "hegrenade_detonate" &&
            Map.get(e.fields, "hegrenade_throw").player_id == attacker_id &&
              Map.get(e.fields, "dmg_health") != "1" ->
            true

          true ->
            false
        end
      end)

    cond do
      event_index != nil ->
        hegrenade_detonate = Enum.at(tmp_events, event_index)
        hegrenade_throw = Map.get(hegrenade_detonate.fields, "hegrenade_throw")

        hegrenade_throw =
          cond do
            user != nil ->
              dmg = Map.get(event.fields, "dmg_health") |> String.to_integer()
              total_dmg = hegrenade_throw.total_damage_dealt + dmg

              {_, map} =
                Map.get_and_update(hegrenade_throw.player_damage_dealt, user_id, fn val ->
                  new_val =
                    cond do
                      val == nil -> dmg
                      true -> dmg + val
                    end

                  {val, new_val}
                end)

              hegrenade_throw
              |> Map.put(:player_damage_dealt, map)
              |> Map.put(:total_damage_dealt, total_dmg)

            true ->
              hegrenade_throw
          end

        hegrenade_detonate = %{
          hegrenade_detonate
          | fields: Map.put(hegrenade_detonate.fields, "hegrenade_throw", hegrenade_throw)
        }

        nade_index =
          Enum.find_index(attacker.grenade_throws, fn gt ->
            gt.tick == hegrenade_throw.tick
          end)

        attacker = %{
          attacker
          | grenade_throws: List.replace_at(attacker.grenade_throws, nade_index, hegrenade_throw)
        }

        {hegrenade_detonate, event_index, attacker, attacker_index}

      true ->
        {nil, nil, nil, nil}
    end
  end

  def process_player_blind_event({player_round_records, tmp_events}, event) do
    {user, _, user_id} = find_player(event, player_round_records)

    {attacker, attacker_index, attacker_id} = find_player(event, player_round_records, "attacker")

    event_index =
      Enum.find_index(tmp_events, fn e ->
        cond do
          GameEvent.is_game_event(e) && e.type == "flashbang_detonate" &&
            Map.get(e.fields, "tick") == Map.get(event.fields, "tick") &&
              Map.get(e.fields, "flashbang_throw").player_id == attacker_id ->
            true

          true ->
            false
        end
      end)

    flashbang_detonate = Enum.at(tmp_events, event_index)
    flashbang_throw = Map.get(flashbang_detonate.fields, "flashbang_throw")

    flashbang_throw =
      cond do
        user != nil ->
          duration = Map.get(event.fields, "blind_duration") |> String.to_float()
          total_blind_duration = flashbang_throw.total_blind_duration + duration

          {_, map} =
            Map.get_and_update(flashbang_throw.player_blind_duration, user_id, fn val ->
              new_val =
                cond do
                  val == nil -> duration
                  true -> duration + val
                end

              {val, new_val}
            end)

          flashbang_throw
          |> Map.put(:player_blind_duration, map)
          |> Map.put(:total_blind_duration, total_blind_duration)

        true ->
          flashbang_throw
      end

    flashbang_detonate = %{
      flashbang_detonate
      | fields: Map.put(flashbang_detonate.fields, "flashbang_throw", flashbang_throw)
    }

    flash_index =
      Enum.find_index(attacker.grenade_throws, fn gt ->
        gt.tick == flashbang_throw.tick
      end)

    attacker = %{
      attacker
      | grenade_throws: List.replace_at(attacker.grenade_throws, flash_index, flashbang_throw)
    }

    player_round_records =
      PlayerRoundRecord.replace_player(player_round_records, attacker_index, attacker)

    tmp_events =
      tmp_events
      |> List.replace_at(event_index, flashbang_detonate)

    {player_round_records, tmp_events}
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
    case GameEvent.get_attacker(event) do
      "0" ->
        {nil, nil, nil}

      _ ->
        find_player(event, player_round_records, "assister")
    end
  end

  def find_player(event, player_round_records, field \\ "userid") do
    [_, id] = GameEvent.process_player_field(event, field)
    user_index = Enum.find_index(player_round_records, fn p -> p.id == id end)
    {Enum.at(player_round_records, user_index || 11), user_index, id}
  end

  def create_assist(nil, _, _, _), do: nil

  def create_assist(assister, victim_name, round_num, tick) do
    %Assist{
      victim_name: victim_name,
      assister_name: assister.name,
      round: round_num,
      tick: tick
    }
  end

  def create_player_round_records(players, round_num) do
    Enum.map(players, fn player_event ->
      [name, id] = GameEvent.process_player_field(player_event)

      team = Map.get(player_event.fields, "team")
      %PlayerRoundRecord{name: name, id: id, team: team, round: round_num}
    end)
  end
end
