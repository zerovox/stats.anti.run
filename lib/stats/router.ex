defmodule Stats.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/summaries" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(getSummaries()))
  end

  defp getSummaries do
    getLeaderboard()
    |> case do
      {:ok, parsed} ->
        parsed
        |> Enum.sort_by(& &1.completed_time)
        |> Enum.map(&Stats.ScoredGame.from_game/1)
    end
  end

  defp getLeaderboard() do
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
