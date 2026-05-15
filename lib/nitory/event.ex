defmodule Nitory.Event do
  @moduledoc """
  Top-level union type for all OneBot events.

  Dispatches `cast/1` based on the `post_type` field to meta events,
  messages, notices, or requests. Echo responses are detected by the
  presence of an `echo` field.
  """

  use Ecto.Type

  alias Nitory.Events.{MetaEvent, IncomingMessage, Notice, Request, Echo}

  @type t :: MetaEvent.t() | IncomingMessage.t() | Notice.t() | Request.t() | Echo.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"post_type" => "meta_event"} = m), do: MetaEvent.cast(m)
  def cast(%{post_type: :meta_event} = m), do: MetaEvent.cast(m)

  def cast(%{"post_type" => "message"} = m), do: IncomingMessage.cast(m)
  def cast(%{post_type: :message} = m), do: IncomingMessage.cast(m)

  def cast(%{"post_type" => "notice"} = m), do: Notice.cast(m)
  def cast(%{post_type: :notice} = m), do: Notice.cast(m)

  def cast(%{"post_type" => "request"} = m), do: Request.cast(m)
  def cast(%{post_type: :request} = m), do: Request.cast(m)

  def cast(%{"echo" => _} = m), do: Echo.new(m)
  def cast(%{echo: _} = m), do: Echo.new(m)

  def cast(t), do: {:error, "Unsupported event: #{inspect(t)}"}

  def dump(_), do: :error

  def load(_), do: :error
end

defmodule Nitory.Event.Types do
  @moduledoc """
  OneBot post type enum.

  Values: `:meta_event`, `:message`, `:notice`, `:request`, `:echo`.
  Used as the discriminator in `Nitory.Event.cast/1`.
  """

  use Flint.Type, extends: Ecto.Enum, values: [:meta_event, :message, :notice, :request, :echo]
end