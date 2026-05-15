defmodule Nitory.Events.Echo do
  @moduledoc """
  Echo (API response) event schema.

  Represents a OneBot action response. Carries a status (`:ok` or `:fail`),
  a return code, arbitrary data, and an echo string used to match it to its
  originating request.
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