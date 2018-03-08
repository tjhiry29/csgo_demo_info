defmodule FlashbangThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :facing,
    :location,
    time_elapsed: 0,
    time_left_in_round: 0,
    player_blind_duration: %{},
    total_blind_duration: 0,
    flash_assist: false,
    detonated: false
  ]

  def is_flashbang_throw(%FlashbangThrow{}) do
    true
  end

  def is_flashbang_throw(_) do
    false
  end

  def update_blind_information(%FlashbangThrow{} = flashbang_throw, nil, _) do
    flashbang_throw
  end

  def update_blind_information(%FlashbangThrow{} = flashbang_throw, user, %GameEvent{} = event) do
    duration = GameEvent.get_blind_duration(event)

    flashbang_throw
    |> update_player_blind_duration(user.id, duration)
    |> update_total_blind_duration(duration)
  end

  def update_blind_information(%FlashbangThrow{} = flashbang_throw, _, _), do: flashbang_throw
  def update_blind_information(_, _, _), do: nil

  def update_total_blind_duration(%FlashbangThrow{} = flashbang_throw, duration) do
    %{flashbang_throw | total_blind_duration: flashbang_throw.total_blind_duration + duration}
  end

  def update_player_blind_duration(%FlashbangThrow{} = flashbang_throw, user_id, duration) do
    {_, map} =
      Map.get_and_update(flashbang_throw.player_blind_duration, user_id, fn val ->
        new_val =
          cond do
            val == nil -> duration
            true -> duration + val
          end

        {val, new_val}
      end)

    %{flashbang_throw | player_blind_duration: map}
  end
end
