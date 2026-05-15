defmodule Nitory.NicknameTest do
  use Nitory.DataCase

  alias Nitory.Nickname
  alias Nitory.Repo

  describe "get_nick/3" do
    test "returns default when no nickname set" do
      assert "DefaultName" = Nickname.get_nick(100, 200, "DefaultName")
    end

    test "returns stored nickname" do
      Nickname.set_nick(101, 201, "CustomNick")
      assert "CustomNick" = Nickname.get_nick(101, 201, "Default")
    end
  end

  describe "set_nick/3" do
    test "creates a new nickname record" do
      assert {:ok, _} = Nickname.set_nick(102, 202, "NewNick")
      assert %{nick: "NewNick"} = Repo.get_by!(Nickname, user_id: 102, group_id: 202)
    end

    test "updates an existing nickname" do
      Nickname.set_nick(103, 203, "First")
      Nickname.set_nick(103, 203, "Second")
      assert %{nick: "Second"} = Repo.get_by!(Nickname, user_id: 103, group_id: 203)
    end
  end

  describe "rm_nick/2" do
    test "removes an existing nickname" do
      Nickname.set_nick(104, 204, "TempNick")
      assert {:ok, _} = Nickname.rm_nick(104, 204)
      assert nil == Repo.get_by(Nickname, user_id: 104, group_id: 204)
    end
  end
end