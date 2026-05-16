# Nitory

[![builds.sr.ht status](https://builds.sr.ht/~naginikaido/nitory-reborn/commits/main/test_only.yml.svg)](https://builds.sr.ht/~naginikaido/nitory-reborn/commits/main/test_only.yml?)

A OneBot-compatible QQ bot framework built with Elixir and Phoenix.
Connects to a OneBot WebSocket client, parses incoming events, and
dispatches commands through a plugin system with composable middleware.

## Architecture

```
WebSocket (OneBot client)
  └── Nitory.Socket              # /bot transport
       └── Nitory.SessionManager # Event dispatch + heartbeat
            ├── Nitory.Session   # Per-chat supervisor
            │    └── Nitory.Robot
            │         ├── Nitory.Middleware  # Composable chain
            │         └── Plugins (GenServer)
            └── Nitory.ApiHandler # OneBot action calls
```

## Quick start

```bash
mix setup          # Install deps + create/migrate DB
mix phx.server     # Start at localhost:4000
```

Connect a OneBot WebSocket client to `ws://localhost:4000/bot`.

## Built-in plugins

| Plugin | Command | Description |
|--------|---------|-------------|
| `Nitory.Plugins.Dice` | `.r` / `.rh` | Dice rolling with rich DSL (keep, explode, arithmetic) |
| `Nitory.Plugins.Help` | `.help` | Command listing and per-command usage |
| `Nitory.Plugins.Khst` | keyword-based | Keyword-to-picture ("看话说图") association |
| `Nitory.Plugins.Nick` | `.nn` | Per-group custom nicknames |

## Writing a plugin

```elixir
defmodule MyPlugin do
  use Nitory.Plugin

  @impl true
  def init_plugin(state) do
    cmds = [
      Nitory.Command.new!(
        display_name: "hello",
        hidden: false,
        short_usage: "Say hello",
        cmd_face: "hello",
        options: [],
        action: {__MODULE__, :say_hello, []},
        usage: ".hello — prints a greeting"
      )
    ]
    %{state | commands: cmds}
  end

  def say_hello(opts) do
    server = Keyword.fetch!(opts, :server)
    GenServer.cast(server, {:send_to_session, :reply, "Hello!"})
  end
end
```

Register in `config/config.exs`:

```elixir
config :nitory, Nitory.Robot, plugins: [MyPlugin]
```

## Key modules

| Module | Role |
|--------|------|
| `Nitory.Socket` | Phoenix socket transport for OneBot WebSocket |
| `Nitory.SessionManager` | Event dispatch, session lifecycle, heartbeat |
| `Nitory.Session` | Per-chat supervisor (group or private) |
| `Nitory.Robot` | Plugin orchestration and command dispatch |
| `Nitory.Middleware` | Composable middleware chain (register / run / dispose) |
| `Nitory.ApiHandler` | OneBot action calls (send_msg, get_image) |
| `Nitory.Command` | Command definition with regex matching and optional args |
| `Nitory.Plugin` | Plugin behaviour and `__using__` macro |
| `Nitory.Event` / `Nitory.Message` | OneBot protocol type schemas |

## Development

```bash
mix compile          # Compile
mix test             # Run tests (78 tests)
mix credo            # Static analysis
mix dialyzer         # Type checking
```

## Release

Burrito releases for macOS (x86_64 / aarch64), Linux (x86_64), Windows:

```bash
MIX_ENV=prod mix release
```

## License

GPL-3.0
