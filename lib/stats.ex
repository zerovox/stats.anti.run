defmodule Stats do
  defmodule Player do
    @derive {Poison.Encoder, []}
    defstruct [:user_id, :type]
  end

  defmodule Hand do
    @derive {Poison.Encoder, []}
    defstruct [:charges, :hearts_won, :queen_winner, :ten_winner, :jack_winner]
  end

  defmodule Game do
    @derive {Poison.Encoder, []}
    defstruct [:game_id, :completed_time, :players, :hands]
  end

  defmodule ScoredHand do
    @derive {Poison.Encoder, []}
    defstruct [:scores]

    def from_hand(
          %Hand{
            charges: charges,
            queen_winner: queen_winner,
            ten_winner: ten_winner,
            jack_winner: jack_winner,
            hearts_won: [hw_p0, hw_p1, hw_p2, hw_p3]
          },
          [p0, p1, p2, p3]
        ) do
      qs_charged = Enum.any?(charges, &Enum.member?(&1, "QS"))
      tc_charged = Enum.any?(charges, &Enum.member?(&1, "TC"))
      jd_charged = Enum.any?(charges, &Enum.member?(&1, "JD"))
      ah_charged = Enum.any?(charges, &Enum.member?(&1, "AH"))

      %ScoredHand{
        scores:
          [
            playerPoints(
              hw_p0,
              queen_winner == p0,
              ten_winner == p0,
              jack_winner == p0,
              qs_charged,
              tc_charged,
              jd_charged,
              ah_charged
            ),
            playerPoints(
              hw_p1,
              queen_winner == p1,
              ten_winner == p1,
              jack_winner == p1,
              qs_charged,
              tc_charged,
              jd_charged,
              ah_charged
            ),
            playerPoints(
              hw_p2,
              queen_winner == p2,
              ten_winner == p2,
              jack_winner == p2,
              qs_charged,
              tc_charged,
              jd_charged,
              ah_charged
            ),
            playerPoints(
              hw_p3,
              queen_winner == p3,
              ten_winner == p3,
              jack_winner == p3,
              qs_charged,
              tc_charged,
              jd_charged,
              ah_charged
            )
          ]
          |> pointsToScore
      }
    end

    defp playerPoints(
           hearts_won,
           qs_won,
           tc_won,
           jd_won,
           qs_charged,
           tc_charged,
           jd_charged,
           ah_charged
         ) do
      ran = hearts_won == 13 and qs_won

      qc_points = if qs_won, do: if(qs_charged, do: 26, else: 13), else: 0
      heart_points = hearts_won * if(ah_charged, do: 2, else: 1)
      bad_points = heart_points + qc_points
      std_points = if ran, do: -bad_points, else: bad_points
      jd_points = if jd_won, do: if(jd_charged, do: -20, else: 10), else: 0
      score = jd_points + std_points
      multiplier = if tc_won, do: if(tc_charged, do: 4, else: 2), else: 0
      multiplier * score
    end

    defp pointsToScore([p0, p1, p2, p3]) do
      [
        p1 - p0 + p2 - p0 + p3 - p0,
        p0 - p1 + p2 - p1 + p3 - p1,
        p0 - p2 + p1 - p2 + p3 - p2,
        p0 - p3 + p1 - p3 + p2 - p3
      ]
    end
  end

  defmodule ScoredGame do
    @derive {Poison.Encoder, []}
    defstruct [:scores, :completed_time]

    def from_game(%Game{hands: hands, players: players, completed_time: completed_time}) do
      player_ids = Enum.map(players, & &1.user_id)

      %ScoredGame{
        scores:
          hands
          |> Enum.map(&Stats.ScoredHand.from_hand(&1, player_ids))
          |> Enum.reduce([0, 0, 0, 0], fn %{scores: [acc0, acc1, acc2, acc3]}, [p0, p1, p2, p3] ->
            [p0 + acc0, p1 + acc1, p2 + acc2, p3 + acc3]
          end)
          # In 1.12.0 - |> Enum.zip_reduce(player_ids, %{}, fn (score, id, acc) -> Map.put(acc, id, score) end)
          |> (&Enum.reduce(Stream.zip(&1, player_ids), %{}, fn {score, id}, acc ->
                Map.put(acc, id, score)
              end)).(),
        completed_time: DateTime.from_unix!(completed_time * 1_000, :microsecond)
      }
    end
  end
end
