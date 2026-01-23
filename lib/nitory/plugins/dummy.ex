defmodule Nitory.Plugins.Dummy do
  use Nitory.Plugin

  @moduledoc """
  A dummy plugin to ensure that the plugin supervisor of Nitory.Robot starts without
  any other plugins.
  """
end
