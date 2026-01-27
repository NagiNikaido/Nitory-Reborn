defmodule Nitory.Session do
  use GenServer
  alias Phoenix.PubSub

  require Logger

  def start_link(arg) do
    {name, init_arg} = Keyword.pop(arg, :name, nil)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  @impl true
  def init(init_arg) do
    session_type = Keyword.fetch!(init_arg, :session_type)
    session_id = Keyword.fetch!(init_arg, :session_id)
    session_prefix = Keyword.fetch!(init_arg, :session_prefix)
    Logger.debug("[#{__MODULE__}] #{inspect(init_arg)}")

    robot = {:via, Registry, {Nitory.SessionSlot, "#{session_prefix}:robot"}}

    children = [
      {Nitory.Robot,
       name: robot,
       session: self(),
       session_id: session_id,
       session_type: session_type,
       session_prefix: session_prefix}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    PubSub.subscribe(Nitory.PubSub, "session:#{session_prefix}")

    {:ok,
     %{
       session_type: session_type,
       session_id: session_id,
       session_prefix: session_prefix,
       robot: robot
     }}
  end

  @impl true
  def handle_info({:message_in, msg}, state) do
    %{robot: robot} = state
    GenServer.cast(robot, {:message_in, msg})
    {:noreply, state}
  end
end
