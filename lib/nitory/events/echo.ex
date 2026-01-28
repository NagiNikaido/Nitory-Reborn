defmodule Nitory.Events.Echo do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :status, Ecto.Enum, values: [:ok, :fail]
    field! :retcode, :integer
    field :data, Union, oneof: [:map, {:array, :any}]
    field! :echo, :string
    field! :post_type, Nitory.Event.Types, default: :echo
  end
end
