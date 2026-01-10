defmodule Nitory.ApiHandlerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup_all do
    start_link_supervised!(Nitory.ApiHandler)
    :ok
  end

  test "cast send_msg apis" do
    Phoenix.PubSub.subscribe(Nitory.PubSub, "session_manager")
    GenServer.cast(Nitory.ApiHandler, {:send_group_msg, %{group_id: 123, message: "123"}})

    echo =
      receive do
        {:api_request,
         %{
           action: :send_group_msg,
           params: %Nitory.ApiHandler.SendGroupMsg.InputSpec{
             group_id: 123,
             message: "123"
           },
           echo: echo
         }} ->
          echo

        data = _ ->
          flunk("Received:\n #{inspect(data, pretty: true)}")
          nil
          # code
      end

    assert echo

    Phoenix.PubSub.broadcast(
      Nitory.PubSub,
      "api_handler",
      {:response,
       Nitory.Events.Echo.new!(%{
         status: :fail,
         retcode: -1,
         echo: echo
       })}
    )
  end

  test "call send_msg apis asynchronously" do
    Phoenix.PubSub.subscribe(Nitory.PubSub, "session_manager")

    task_1 =
      Task.async(fn ->
        GenServer.call(Nitory.ApiHandler, {:send_group_msg, %{group_id: 123, message: "123"}})
      end)

    echo_1 =
      receive do
        {
          :api_request,
          %{
            action: :send_group_msg,
            params: %Nitory.ApiHandler.SendGroupMsg.InputSpec{
              group_id: 123,
              message: "123"
            },
            echo: echo
          }
        } ->
          echo

        data = _ ->
          flunk("Received:\n#{inspect(data, pretty: true)}")
          nil
          # code
      end

    assert echo_1

    task_2 =
      Task.async(fn ->
        GenServer.call(Nitory.ApiHandler, {:send_private_msg, %{user_id: 456, message: "456"}})
      end)

    echo_2 =
      receive do
        {
          :api_request,
          %{
            action: :send_private_msg,
            params: %Nitory.ApiHandler.SendPrivateMsg.InputSpec{
              user_id: 456,
              message: "456"
            },
            echo: echo
          }
        } ->
          echo

        data = _ ->
          flunk("Received:\n#{inspect(data, pretty: true)}")
          nil
      end

    assert echo_2

    Phoenix.PubSub.broadcast(
      Nitory.PubSub,
      "api_handler",
      {:response,
       Nitory.Events.Echo.new!(%{
         status: :ok,
         retcode: 0,
         data: %{message_id: 456},
         echo: echo_2
       })}
    )

    assert Task.await(task_2) ==
             {:ok, %Nitory.ApiHandler.SendPrivateMsg.OutputSpec{message_id: 456}}

    Phoenix.PubSub.broadcast(
      Nitory.PubSub,
      "api_handler",
      {:response,
       Nitory.Events.Echo.new!(%{
         status: :ok,
         retcode: 0,
         data: %{message_id: 123},
         echo: echo_1
       })}
    )

    assert Task.await(task_1) ==
             {:ok, %Nitory.ApiHandler.SendGroupMsg.OutputSpec{message_id: 123}}
  end
end
