defmodule Nitory.Plugins.Khst do
  use Nitory.Plugin
  import Ecto.Query, only: [from: 2]

  defmodule Picture do
    use Ecto.Schema

    schema "khst_picture" do
      field :hash_sum, :string
      field :path, :string
      has_many :keywords, Nitory.Plugins.Khst.Keyword2Picture
      has_many :history, Nitory.Plugins.Khst.History
    end
  end

  defmodule Keyword2Picture do
    use Ecto.Schema

    schema "khst_keyword2picture" do
      field :keyword, :string
      field :group_id, :integer
      field :tag, :string
      belongs_to :picture, Nitory.Plugins.Khst.Picture
    end
  end

  defmodule History do
    use Ecto.Schema

    schema "khst_history" do
      field :message_id, :integer
      field :keyword, :string
      field :group_id, :integer
      belongs_to :picture, Nitory.Plugins.Khst.Picture
    end
  end

  def proper_keyword?(maybe_keyword), do: not String.starts_with?(maybe_keyword, [".", "/"])
  def proper_tags?(maybe_tags), do: maybe_tags =~ ~r/^([+\-].+)*$/

  def split_msg(msg) do
    if msg.message_type == :group and
         (is_binary(msg.message) or
            (length(msg.message) == 1 and List.first(msg.message).type == :text)) do
      raw_msg =
        if is_binary(msg.message), do: msg.message, else: List.first(msg.message).data.text

      case String.split(raw_msg) do
        [raw_keyword] ->
          if proper_keyword?(raw_keyword) do
            {:ok, raw_keyword, ""}
          else
            :error
          end

        [raw_keyword, raw_tags] ->
          if proper_keyword?(raw_keyword) and proper_tags?(raw_tags) do
            {:ok, raw_keyword, raw_tags}
          else
            :error
          end

        _ ->
          :error
      end
    else
      :error
    end
  end

  defp image_ext("image/" <> ext = _mime_type), do: ext

  defp get_remote(url) do
    with {:ok, response} <- Req.get(url),
         %{status: 200, headers: %{"content-type" => [mime_type]}, body: body} <- response do
      shasum = :crypto.hash(:sha, body) |> Base.encode16() |> String.downcase()
      ext = image_ext(mime_type)
      {:ok, body, shasum, ext}
    else
      _ -> {:error, "* 保存图片失败：下载错误"}
    end
  end

  defp add_picture(keyword, group_id, hash_sum, path) do
    Nitory.Repo.transact(fn repo ->
      existing_pic = Nitory.Repo.get_by(Picture, hash_sum: hash_sum)
      first_met = existing_pic == nil

      keyword_line = %{keyword: keyword, group_id: group_id, tag: ""}

      res =
        if first_met do
          repo.insert(%Picture{
            hash_sum: hash_sum,
            path: path,
            keywords: [%Keyword2Picture{keyword: keyword, group_id: group_id, tag: ""}]
          })
        else
          existing_pic
          |> Ecto.build_assoc(:keywords, keyword_line)
          |> repo.insert()
        end

      case res do
        {:ok, _} ->
          count = length(repo.all_by(Keyword2Picture, keyword_line))
          {:ok, {first_met, count}}

        _ ->
          res
      end
    end)
  end

  defp get_pictures_by_keyword(keyword, group_id) do
    query =
      from k in Keyword2Picture,
        where: k.keyword == ^keyword and k.group_id == ^group_id,
        join: p in Picture,
        on: p.id == k.picture_id,
        select: p,
        order_by: p.hash_sum

    case Nitory.Repo.all(query) do
      [] -> {:error, :empty_list}
      res -> {:ok, res}
    end
  end

  defp add_history(message_id, keyword, group_id, hash_sum) do
    res =
      Nitory.Repo.transact(fn repo ->
        repo.get_by!(Picture, hash_sum: hash_sum)
        |> Ecto.build_assoc(:history, %{
          message_id: message_id,
          keyword: keyword,
          group_id: group_id
        })
        |> repo.insert()
      end)

    case res do
      {:ok, _} -> res
      {:error, _} -> {:error, "* 保存看话说图历史失败"}
    end
  end

  defp save_picture(path, content) do
    case File.write(path, content) do
      :ok -> :ok
      {:error, eno} -> {:error, "* 保存图片失败：本地错误#{eno}"}
    end
  end

  def save_remote_and_add_picture(url, keyword, group_id, path_prefix, message_id) do
    Nitory.Repo.transact(fn ->
      with {:ok, content, hash_sum, ext} <- get_remote(url),
           rel_path = "#{hash_sum}.#{ext}",
           path = Path.join(path_prefix, rel_path),
           {:ok, {first_met, count}} <- add_picture(keyword, group_id, hash_sum, rel_path),
           {:ok, _} <- add_history(message_id, keyword, group_id, hash_sum),
           :ok <- if(first_met, do: save_picture(path, content), else: :ok) do
        {:ok, "* 已添加图片 #{keyword}#{count}"}
      else
        error -> error
      end
    end)
  end

  def pick_responding_picture(keyword, path_prefix, group_id) do
    res =
      Nitory.Repo.transact(fn ->
        with {:ok, pics} <- get_pictures_by_keyword(keyword, group_id),
             pic = List.first(Enum.take_random(pics, 1)),
             uri = URI.merge("file://", Path.join(path_prefix, pic.path)),
             msg = [Nitory.Message.Segment.Image.new!(%{data: %{file: to_string(uri)}})],
             {:ok, data} =
               GenServer.call(
                 Nitory.ApiHandler,
                 {:send_group_msg, %{group_id: group_id, message: msg}}
               ),
             {:ok, _} <- add_history(data.message_id, keyword, group_id, pic.hash_sum) do
          {:ok, :ok}
        else
          error -> error
        end
      end)

    case res do
      {:ok, _} -> :ok
      _ -> res
    end
  end

  def remove_k2p_by_history(message_id, group_id) do
    Nitory.Repo.transact(fn repo ->
      existing_history = repo.get_by(History, message_id: message_id, group_id: group_id)

      if existing_history == nil do
        {:error, "* 未找到看话说图记录。是否回复错误？"}
      else
        query =
          from k in Keyword2Picture,
            where:
              k.keyword == ^existing_history.keyword and
                k.group_id == ^group_id and
                k.picture_id == ^existing_history.picture_id

        {res, _} = repo.delete_all(query)

        if res == 0 do
          {:error, "* 该图片已不在关键词\"#{existing_history.keyword}\"的条目中。是否已被删除？"}
        else
          {:ok, "* 已从关键词\"#{existing_history.keyword}\"的条目中删除了该图片"}
        end
      end
    end)
  end

  @impl true
  def capture_extra_args(opts) do
    path_prefix = Keyword.get(opts, :path_prefix, ".")
    File.mkdir_p!(path_prefix)
    %{recv_dispose_handle: nil, path_prefix: path_prefix}
  end

  @impl true
  def handle_call({:capture_keyword_and_respond, _msg, keyword, _raw_tags}, _from, state) do
    # Here it's guarenteed that the incoming message is a group and text-only message.
    resp = pick_responding_picture(keyword, state.path_prefix, state.session_id)
    {:reply, resp, state}
  end

  @impl true
  def handle_call({:add_khst, msg, keyword}, _from, state) do
    server = self()
    cur_user_id = msg.user_id

    dispose =
      Nitory.Middleware.register(
        state.middleware,
        fn msg, next ->
          if msg.user_id == cur_user_id do
            if not is_list(msg.message) or length(msg.message) != 1 or
                 List.first(msg.message).type != :image do
              {:error, "* 并非图片"}
            else
              GenServer.call(server, {:received_image, msg, keyword})
            end
          else
            Nitory.Middleware.run(msg, next)
          end
        end,
        :prepend
      )

    {:reply, {:ok, "* 等待添加图片中"}, %{state | recv_dispose_handle: dispose}}
  end

  @impl true
  def handle_call({:received_image, msg, keyword}, _from, state) do
    dispose_handle = state.recv_dispose_handle
    dispose_handle.()

    resp =
      save_remote_and_add_picture(
        List.first(msg.message).data.url,
        keyword,
        state.session_id,
        state.path_prefix,
        msg.message_id
      )

    {:reply, resp, %{state | recv_dispose_handle: nil}}
  end

  @impl true
  def handle_call({:remove_khst, _msg, reply}, _from, state) do
    resp =
      if reply == nil do
        {:error, "* 格式错误"}
      else
        remove_k2p_by_history(reply, state.session_id)
      end

    {:reply, resp, state}
  end

  def cmd_khst(opts) do
    msg = Keyword.fetch!(opts, :msg)
    keyword = Keyword.fetch!(opts, :keyword)
    server = Keyword.fetch!(opts, :server)

    GenServer.call(server, {:add_khst, msg, keyword})
  end

  def cmd_remove(opts) do
    msg = Keyword.fetch!(opts, :msg)
    reply = Keyword.fetch!(opts, :reply)
    server = Keyword.fetch!(opts, :server)

    GenServer.call(server, {:remove_khst, msg, reply})
  end

  @impl true
  def init_plugin(state) do
    server = self()

    Nitory.Middleware.register(state.middleware, fn msg, next ->
      with {:ok, keyword, raw_tags} <- __MODULE__.split_msg(msg),
           {:ok, resp} <-
             GenServer.call(server, {:capture_keyword_and_respond, msg, keyword, raw_tags}) do
        {:ok, resp}
      else
        {:error, msg} when is_binary(msg) -> {:error, msg}
        _ -> Nitory.Middleware.run(msg, next)
      end
    end)

    commands = [
      Nitory.Command.new!(
        display_name: "khst",
        hidden: false,
        msg_type: :group,
        short_usage: "看话说图",
        cmd_face: "khst",
        options: [%Nitory.Command.Option{name: :keyword, optional: false}],
        action: {__MODULE__, :cmd_khst, []},
        usage: """
        看话说图
        .khst [关键词]  为关键词添加随机图片项
        输入指令后 bot 会进入交互模式，等待输入指令者发出图片。
        添加完成后，再次输入关键词，bot 便会从已添加的所有图片中随机选取一张发出。
        如果在关键词之后附加标签，则会在符合标签的图片中随机选取一张发出，如：
        （以下用>表示信息从用户处发出，用<表示信息从bot处发出）
        1> .khst test
        2> [图片]
        3< (添加成功信息)
        4> [引用信息2] .tag +good
        5< (添加成功信息)
        6> test +good
        7< [信息2中图片]
        8> test -good
        9< * 没有合适的图片……
        """
      ),
      Nitory.Command.new!(
        display_name: "rm",
        hidden: false,
        msg_type: :group,
        short_usage: "删除看话说图条目",
        cmd_face: "rm",
        options: [],
        action: {__MODULE__, :cmd_remove, []},
        usage: """
        删除看话说图条目
        选中 bot 发出的图回复 .rm 即可将该图从对应关键词中删除
        """
      )
      # Nitory.Command.new!(
      #   display_name: "tag",
      #   hidden: false,
      #   msg_type: :group,
      #   short_usage: "修改或查看看话说图条目的标签",
      #   cmd_face: "tag",
      #   options: [%Nitory.Command.Option{name: :tags, optional: true}],
      #   action: {__MODULE__, :cmd_tag, []},
      #   usage: """
      #   修改或查看看话说图条目的标签
      #   选中图片回复 .tag 即可查看该图现有标签
      #   回复 .tag [+/-标签] 即可添加或删除对应标签
      #   回复 .tag ! 即可清空该图现有标签
      #   回复 .tag ![+/-标签] 即可清空现有标签，并添加新的标签
      #   可同时增减多枚标签，如
      #   .tag +美味-搞笑        为图片添加"美味"标签，并删除"搞笑"标签
      #   .tag !+美味+搞笑-音乐   清空现有标签，并为图片添加"美味"和"搞笑"标签，并删除"音乐"标签（由于已被清空，因此该删除操作并无实际效果）
      #   """
      # )
    ]

    %{state | commands: commands}
  end
end
