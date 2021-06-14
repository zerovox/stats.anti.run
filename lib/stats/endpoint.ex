defmodule Stats.Endpoint do
  use Plug.Router
  use Plug.ErrorHandler
  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts) do
    with {:ok, [port: port] = config} <- Application.fetch_env(:stats, __MODULE__) do
      Logger.info("Starting server at http://localhost:#{port}/")
      Plug.Cowboy.http(__MODULE__, [], config)
    end
  end

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(:dispatch)

  forward("/stats", to: Stats.Router)

  match _ do
    send_resp(conn, 404, "Not found.")
  end

  defp handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    case reason do
      %{message: message} when is_binary(message) ->
        send_resp(conn, conn.status, "Something went wrong: " <> message)

      %{} ->
        send_resp(conn, conn.status, "Something went wrong")
    end
  end
end
