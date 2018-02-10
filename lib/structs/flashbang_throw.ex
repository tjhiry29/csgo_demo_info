defmodule FlashbangThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :facing,
    :location,
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

  def update_blind_information(%FlashbangThrow{} = hegrenade_throw, nil, _) do
    hegrenade_throw
  end

  def update_blind_information(%FlashbangThrow{} = flashbang_throw, user_id, event) do
    duration = GameEvent.get_blind_duration(event)

    flashbang_throw
    |> update_player_blind_duration(user_id, duration)
    |> update_total_blind_duration(duration)
  end

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
