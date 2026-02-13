defmodule Nitory.Plugin do
  defmacro __using__(_opt) do
    quote location: :keep do
      use GenServer
      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
      alias Nitory.Command.Option

      require Logger

      def start_link(arg) do
        {name, init_arg} = Keyword.pop(arg, :name, nil)
        GenServer.start_link(__MODULE__, init_arg, name: name)
      end

      @impl true
      def plugin_name, do: "#{__MODULE__}"

      @impl true
      def init(init_arg) do
        Logger.debug("[#{__MODULE__}] #{inspect(init_arg)}")
        {session, init_arg} = Keyword.pop!(init_arg, :session)
        {session_id, init_arg} = Keyword.pop!(init_arg, :session_id)
        {session_type, init_arg} = Keyword.pop!(init_arg, :session_type)
        {session_prefix, init_arg} = Keyword.pop!(init_arg, :session_prefix)
        {middleware, init_arg} = Keyword.pop!(init_arg, :middleware)
        {robot, init_arg} = Keyword.pop!(init_arg, :robot)
        extra_args = capture_extra_args(init_arg)

        {:ok,
         Map.merge(extra_args, %{
           session: session,
           session_id: session_id,
           session_type: session_type,
           session_prefix: session_prefix,
           middleware: middleware,
           commands: [],
           robot: robot
         })}
      end

      @impl true
      def capture_extra_args(_), do: %{}

      @impl true
      def init_plugin(state), do: state

      defoverridable(init_plugin: 1, capture_extra_args: 1)

      @impl true
      def handle_call({:deferred_init}, _from, state), do: {:reply, :ok, init_plugin(state)}

      @impl true
      def handle_call({:list_commands}, _from, state), do: {:reply, state.commands, state}
    end
  end

  @callback capture_extra_args(keyword()) :: map()
  @callback init_plugin(map()) :: map()
  @callback plugin_name() :: String.t()
end
