defmodule Nitory.Events.Request.Types do
  use Flint.Type, extends: Ecto.Enum, values: [:friend, :group]
end

defmodule Nitory.Events.Request.FriendRequest do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Events.Types
    field! :request_type, Nitory.Events.Request.Types
    field! :user_id, :integer
    field! :comment, :string
    field! :flag, :string
  end
end

defmodule Nitory.Events.Request.GroupRequest do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Events.Types
    field! :request_type, Nitory.Events.Request.Types
    field! :user_id, :integer
    field! :comment, :string
    field! :flag, :string
    field! :sub_type, Ecto.Enum, values: [:add, :invite]
  end
end

defmodule Nitory.Events.Request do
  use Ecto.Type

  alias Nitory.Events.Request.{FriendRequest, GroupRequest}

  @type t :: FriendRequest.t() | GroupRequest.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"request_type" => "friend"} = m), do: FriendRequest.cast(m)
  def cast(%{request_type: :friend} = m), do: FriendRequest.cast(m)

  def cast(%{"request_type" => "group"} = m), do: GroupRequest.cast(m)
  def cast(%{request_type: :group} = m), do: GroupRequest.cast(m)

  def cast(t), do: {:error, "Unsupported request event: #{inspect(t)}"}

  def dump(_), do: :error

  def load(_), do: :error
end
