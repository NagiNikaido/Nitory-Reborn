defmodule Nitory.Plugin do
  defmacro __using__(_opt) do
    module = __CALLER__.module
    Module.register_attribute(module, :commands, accumulate: true)
    Module.register_attribute(module, :visible_commands, accumulate: true)

    quote location: :keep do
      use GenServer
      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
      alias Nitory.Command.Option

      def start_link(arg) do
        {name, init_arg} = Keyword.pop(arg, :name, nil)
        GenServer.start_link(__MODULE__, init_arg, name: name)
      end

      @impl true
      def plugin_name, do: "#{__MODULE__}"

      @impl true
      def init(init_arg) do
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
           robot: robot
         })}
      end

      @impl true
      def list_commands(show_hidden) do
        if show_hidden do
          @commands
        else
          @visible_commands
        end
      end

      @impl true
      def capture_extra_args(_), do: %{}

      @impl true
      def init_plugin(state), do: state

      defoverridable(init_plugin: 1, capture_extra_args: 1)

      @impl true
      def handle_cast({:deferred_init}, state), do: {:noreply, init_plugin(state)}
    end
  end

  defmacro defcommand(opts) do
    module = __CALLER__.module

    opts =
      Enum.map(opts, fn {key, val} -> {key, elem(Code.eval_quoted(val, [], __CALLER__), 0)} end)

    IO.inspect(opts)

    {:ok, command} = Nitory.Command.new(opts)

    Module.put_attribute(module, :commands, command)

    if not command.hidden do
      Module.put_attribute(module, :visible_commands, command)
    end

    quote do
    end
  end

  @callback list_commands(boolean()) :: [Nitory.Command.t()]
  @callback capture_extra_args(keyword()) :: map()
  @callback init_plugin(map()) :: map()
  @callback plugin_name() :: String.t()
end
