defmodule Nitory.Events.Echo do
  @moduledoc """
  Echo (API response) event schema.

  Represents a OneBot action response. Carries a status (`:ok` or `:fail`),
  a return code, arbitrary data, and an echo string used to match it to its
  originating request.

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `status` | `:ok` / `:fail` | yes | Result status |
  | `retcode` | `integer()` | yes | Return code (0 = success) |
  | `data` | map / array / any | no | Response payload |
  | `echo` | `String.t()` | yes | Echo string matching request serial |

  ## Deserialization (JSON → struct)

      iex> {:ok, ev} = Nitory.Events.Echo.cast(%{
      ...>   "status" => "ok", "retcode" => 0,
      ...>   "data" => %{"message_id" => 123},
      ...>   "echo" => "1"
      ...> })
      iex> ev.status
      :ok
      iex> ev.echo
      "1"

  ## Serialization (struct → map)

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Events.Echo{
      ...>   status: :ok, retcode: 0,
      ...>   data: %{message_id: 123}, echo: "1",
      ...>   post_type: :echo
      ...> })
      %{status: :ok, retcode: 0, data: %{message_id: 123}, echo: "1", post_type: :echo}
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :status, Ecto.Enum, values: [:ok, :fail]
    field! :retcode, :integer
    field :data, Union, oneof: [:map, {:array, :any}]
    field! :echo, :string
    field! :post_type, Nitory.Event.Types, default: :echo
  end
end
