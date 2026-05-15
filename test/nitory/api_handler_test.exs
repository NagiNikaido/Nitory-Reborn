defmodule Nitory.ApiHandlerTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  setup do
    unless Process.whereis(Nitory.ApiHandler) do
      start_link_supervised!(Nitory.ApiHandler)
    end
    :ok
  end

  def get_proper_io(action, id, msg, msg_id)

  def get_proper_io(:send_group_msg, id, msg, msg_id) do
    input = {:send_group_msg, %{group_id: id, message: msg}}
    output = %Nitory.ApiHandler.SendGroupMsg.OutputSpec{message_id: msg_id}
    {input, output}
  end

  def get_proper_io(:send_private_msg, id, msg, msg_id) do
    input = {:send_private_msg, %{user_id: id, message: msg}}
    output = %Nitory.ApiHandler.SendPrivateMsg.OutputSpec{message_id: msg_id}
    {input, output}
  end

  test "call send_*_msg apis asynchronously" do
    Phoenix.PubSub.subscribe(Nitory.PubSub, "session_manager")

    check all(
            id <- integer(1..1_048_576),
            message_id <- integer(1..1_048_576),
            message <- string(:alphanumeric),
            action <- member_of([:send_group_msg, :send_private_msg]),
            message != "",
            initial_size: 2000
          ) do
      {input, output} = get_proper_io(action, id, message, message_id)

      task =
        Task.async(fn ->
          GenServer.call(Nitory.ApiHandler, input)
        end)

      echo = await_api_request(action, id, message)

      assert {^action, _} = echo

      {^action, real_echo} = echo

      Phoenix.PubSub.broadcast(
        Nitory.PubSub,
        "api_handler",
        {:response,
         Nitory.Events.Echo.new!(%{
           status: :ok,
           retcode: 0,
           data: %{message_id: message_id},
           echo: real_echo
         })}
      )

      assert Task.await(task) == {:ok, output}
    end
  end

  defp await_api_request(action, id, message) do
    receive do
      {:api_request,
       %{
         action: :send_group_msg,
         params: %Nitory.ApiHandler.SendGroupMsg.InputSpec{
           group_id: ^id,
           message: ^message
         },
         echo: echo
       }} ->
        {:send_group_msg, echo}

      {:api_request,
       %{
         action: :send_private_msg,
         params: %Nitory.ApiHandler.SendPrivateMsg.InputSpec{
           user_id: ^id,
           message: ^message
         },
         echo: echo
       }} ->
        {:send_private_msg, echo}

      {:api_request, _unexpected} ->
        await_api_request(action, id, message)

      other ->
        flunk("Unexpected message: #{inspect(other)}")
    after
      5_000 ->
        flunk("Timeout waiting for api_request (action=#{action}, id=#{id})")
    end
  end
end
