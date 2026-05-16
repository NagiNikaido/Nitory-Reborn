defmodule Nitory.Events.Notice.Types do
  @moduledoc """
  OneBot notice type enum.

  Values: `:group_admin`, `:group_ban`, `:group_decrease`, `:group_increase`,
  `:group_recall`, `:group_upload`, `:friend_add`, `:friend_recall`.
  """

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
  @moduledoc """
  OneBot group file upload notice (`notice_type: "group_upload"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:group_upload` | yes | Notice type discriminator |
  | `group_id` | `integer()` | yes | Group ID |
  | `user_id` | `integer()` | yes | Uploader's QQ number |
  | `file.id` | `String.t()` | yes | File ID |
  | `file.name` | `String.t()` | yes | File name |
  | `file.size` | `integer()` | yes | File size (bytes) |
  | `file.busid` | `integer()` | yes | Business ID |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.GroupUpload.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "group_upload", "group_id" => 1, "user_id" => 2,
      ...>   "file" => %{"id" => "f1", "name" => "doc.pdf", "size" => 1024, "busid" => 0}
      ...> })
      iex> ev.file.name
      "doc.pdf"
  """

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
  @moduledoc """
  OneBot group admin change notice (`notice_type: "group_admin"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:group_admin` | yes | Notice type discriminator |
  | `sub_type` | `:set` / `:unset` | yes | `:set` = promoted, `:unset` = demoted |
  | `group_id` | `integer()` | yes | Group ID |
  | `user_id` | `integer()` | yes | Target user's QQ number |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.GroupAdmin.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "group_admin", "sub_type" => "set",
      ...>   "group_id" => 1, "user_id" => 2
      ...> })
      iex> ev.sub_type
      :set
  """

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
  @moduledoc """
  OneBot group member decrease notice (`notice_type: "group_decrease"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:group_decrease` | yes | Notice type discriminator |
  | `sub_type` | `:leave` / `:kick` / `:kick_me` / `:disband` | yes | How the member left |
  | `group_id` | `integer()` | yes | Group ID |
  | `user_id` | `integer()` | yes | User who left/was kicked |
  | `operator_id` | `integer()` | yes | Operator who performed the action |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.GroupDecrease.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "group_decrease", "sub_type" => "leave",
      ...>   "group_id" => 1, "user_id" => 2, "operator_id" => 3
      ...> })
      iex> ev.sub_type
      :leave
  """

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
  @moduledoc """
  OneBot group member increase notice (`notice_type: "group_increase"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:group_increase` | yes | Notice type discriminator |
  | `sub_type` | `:approve` / `:invite` | yes | `:approve` = admin approved, `:invite` = invited |
  | `group_id` | `integer()` | yes | Group ID |
  | `user_id` | `integer()` | yes | New member's QQ number |
  | `operator_id` | `integer()` | yes | Operator who approved/invited |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.GroupIncrease.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "group_increase", "sub_type" => "invite",
      ...>   "group_id" => 1, "user_id" => 2, "operator_id" => 3
      ...> })
      iex> ev.sub_type
      :invite
  """

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
  @moduledoc """
  OneBot group ban/mute notice (`notice_type: "group_ban"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:group_ban` | yes | Notice type discriminator |
  | `sub_type` | `:ban` / `:lift_ban` | yes | `:ban` = muted, `:lift_ban` = unmuted |
  | `group_id` | `integer()` | yes | Group ID |
  | `user_id` | `integer()` | yes | Target user's QQ number |
  | `operator_id` | `integer()` | yes | Operator who performed the action |
  | `duration` | `integer()` | yes | Ban duration in seconds |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.GroupBan.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "group_ban", "sub_type" => "ban",
      ...>   "group_id" => 1, "user_id" => 2, "operator_id" => 3, "duration" => 600
      ...> })
      iex> ev.duration
      600
  """

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
  @moduledoc """
  OneBot group message recall notice (`notice_type: "group_recall"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:group_recall` | yes | Notice type discriminator |
  | `group_id` | `integer()` | yes | Group ID |
  | `user_id` | `integer()` | yes | Original message sender's QQ number |
  | `operator_id` | `integer()` | yes | Operator who recalled the message |
  | `message_id` | `integer()` | yes | Recalled message ID |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.GroupRecall.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "group_recall", "group_id" => 1,
      ...>   "user_id" => 2, "operator_id" => 3, "message_id" => 100
      ...> })
      iex> ev.message_id
      100
  """

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
  @moduledoc """
  OneBot friend added notice (`notice_type: "friend_add"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:friend_add` | yes | Notice type discriminator |
  | `user_id` | `integer()` | yes | New friend's QQ number |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.FriendAdd.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "friend_add", "user_id" => 2
      ...> })
      iex> ev.user_id
      2
  """

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
  @moduledoc """
  OneBot friend message recall notice (`notice_type: "friend_recall"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:notice` | yes | Event post type |
  | `notice_type` | `:friend_recall` | yes | Notice type discriminator |
  | `user_id` | `integer()` | yes | Sender's QQ number |
  | `message_id` | `integer()` | yes | Recalled message ID |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Notice.FriendRecall.cast(%{
      ...>   "time" => 1, "self_id" => 1, "post_type" => "notice",
      ...>   "notice_type" => "friend_recall", "user_id" => 2, "message_id" => 100
      ...> })
      iex> ev.message_id
      100
  """

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
  @moduledoc """
  Union type for OneBot notice events.

  Dispatches `cast/1` to the relevant notice sub-type based on the
  `notice_type` field. Some notice types (poke, lucky_king, honor, etc.)
  are not yet implemented.
  """

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

  @doc false
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

  @doc false
  def dump(_), do: :error

  @doc false
  def load(_), do: :error
end
