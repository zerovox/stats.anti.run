defmodule Stats.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/summaries" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(get_summaries()))
  end

  get "/cumulative" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(get_cumulative()))
  end

  defp get_summaries do
    get_leaderboard()
    |> case do
      {:ok, parsed} ->
        parsed
        |> Enum.sort_by(& &1.completed_time)
        |> Enum.map(&Stats.ScoredGame.from_game/1)
    end
  end

  defp get_cumulative do
    {:ok, parsed_games} = get_leaderboard()

    scored_games =
      parsed_games
      |> Enum.sort_by(& &1.completed_time)
      |> Enum.map(&Stats.ScoredGame.from_game/1)

    players = get_players(parsed_games)

    players
    |> Enum.map(&get_player_score_series(&1, scored_games))
    # Poison can't handle tuples, so we explicitly convert to a map.
    |> Enum.map(&Enum.map(&1, fn {time, score} -> %{time: time, score: score} end))
  end

  defp get_players(parsed_games) do
    Enum.flat_map(parsed_games, &Enum.map(&1.players, fn player -> player.user_id end))
    |> Enum.reduce(MapSet.new(), &MapSet.put(&2, &1))
  end

  defp get_player_score_series(user_id, scored_games) do
    scored_games
    |> Enum.map(fn %Stats.ScoredGame{completed_time: completed_time, scores: scores} ->
      {completed_time, Map.get(scores, user_id, 0)}
    end)
    |> Enum.filter(fn {_, score} -> score != 0 end)
    |> Enum.map_reduce(0, fn {time, score}, total -> {{time, total + score}, total + score} end)
    |> (fn {series, _total} -> series end).()
  end

  defp get_leaderboard() do
    HTTPoison.get("https://play.anti.run/summary/leaderboard?page_size=10000", [])
    |> case do
      {:ok, %{body: raw, status_code: code}} -> {code, raw}
      {:error, %{reason: reason}} -> {:error, reason}
    end
    |> case do
      {code, body} when code == 200 ->
        body
        |> Poison.decode(as: [%Stats.Game{hands: [%Stats.Hand{}], players: [%Stats.Player{}]}])
        |> case do
          {:ok, parsed} -> {:ok, parsed}
          _ -> {:error, body}
        end

      {code, _reason} ->
        {:error, code}
    end
  end
end
