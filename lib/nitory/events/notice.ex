defmodule Nitory.Events.Notice.Types do
  use Flint.Type,
    extends: Ecto.Enum,
    values: [
      :group_admin,
      :group_ban,
      :group_decrease,
      :group_increase,
      :group_recall,
      :group_upload,
      :friend_add,
      :friend_recall
    ]
end

defmodule Nitory.Events.Notice.GroupUpload do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :group_id, :integer
    field! :user_id, :integer

    embeds_one! :file, File do
      field! :id, :string
      field! :name, :string
      field! :size, :integer
      field! :busid, :integer
    end
  end
end

defmodule Nitory.Events.Notice.GroupAdmin do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :group_id, :integer
    field! :user_id, :integer
    field! :sub_type, Ecto.Enum, values: [:set, :unset]
  end
end

defmodule Nitory.Events.Notice.GroupDecrease do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :group_id, :integer
    field! :user_id, :integer
    field! :operator_id, :integer
    field! :sub_type, Ecto.Enum, values: [:leave, :kick, :kick_me, :disband]
  end
end

defmodule Nitory.Events.Notice.GroupIncrease do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :group_id, :integer
    field! :user_id, :integer
    field! :operator_id, :integer
    field! :sub_type, Ecto.Enum, values: [:approve, :invite]
  end
end

defmodule Nitory.Events.Notice.GroupBan do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :group_id, :integer
    field! :operator_id, :integer
    field! :user_id, :integer
    field! :duration, :integer
    field! :sub_type, Ecto.Enum, values: [:ban, :lift_ban]
  end
end

defmodule Nitory.Events.Notice.GroupRecall do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :group_id, :integer
    field! :user_id, :integer
    field! :operator_id, :integer
    field! :message_id, :integer
  end
end

defmodule Nitory.Events.Notice.FriendAdd do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :user_id, :integer
  end
end

defmodule Nitory.Events.Notice.FriendRecall do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :notice_type, Nitory.Events.Notice.Types
    field! :user_id, :integer
    field! :message_id, :integer
  end
end

defmodule Nitory.Events.Notice do
  use Ecto.Type

  alias Nitory.Events.Notice.{
    GroupAdmin,
    GroupBan,
    GroupDecrease,
    GroupIncrease,
    GroupRecall,
    GroupUpload,
    FriendAdd,
    FriendRecall

    # TODO: poke, lucky_king, honor, group_msg_emoji_like, essence, group_card
  }

  @type t ::
          GroupAdmin.t()
          | GroupBan.t()
          | GroupDecrease.t()
          | GroupIncrease.t()
          | GroupRecall.t()
          | GroupUpload.t()
          | FriendAdd.t()
          | FriendRecall.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"notice_type" => "group_admin"} = m), do: GroupAdmin.cast(m)
  def cast(%{notice_type: :group_admin} = m), do: GroupAdmin.cast(m)

  def cast(%{"notice_type" => "group_ban"} = m), do: GroupBan.cast(m)
  def cast(%{notice_type: :group_ban} = m), do: GroupBan.cast(m)

  def cast(%{"notice_type" => "group_decrease"} = m), do: GroupDecrease.cast(m)
  def cast(%{notice_type: :group_decrease} = m), do: GroupDecrease.cast(m)

  def cast(%{"notice_type" => "group_increase"} = m), do: GroupIncrease.cast(m)
  def cast(%{notice_type: :group_increase} = m), do: GroupIncrease.cast(m)

  def cast(%{"notice_type" => "group_recall"} = m), do: GroupRecall.cast(m)
  def cast(%{notice_type: :group_recall} = m), do: GroupRecall.cast(m)

  def cast(%{"notice_type" => "group_upload"} = m), do: GroupUpload.cast(m)
  def cast(%{notice_type: :group_upload} = m), do: GroupUpload.cast(m)

  def cast(%{"notice_type" => "friend_add"} = m), do: FriendAdd.cast(m)
  def cast(%{notice_type: :friend_add} = m), do: FriendAdd.cast(m)

  def cast(%{"notice_type" => "friend_recall"} = m), do: FriendRecall.cast(m)
  def cast(%{notice_type: :friend_recall} = m), do: FriendRecall.cast(m)

  def cast(t), do: {:error, "Unsupported notice event: #{inspect(t)}"}

  def dump(_), do: :error

  def load(_), do: :error
end
