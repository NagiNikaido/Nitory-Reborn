defmodule Nitory.NicknameTest do
  use Nitory.DataCase
  use ExUnitProperties

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

  describe "property-based tests" do
    test "set_nick then get_nick roundtrips" do
      check all(
              user_id <- integer(1_000..9_999),
              group_id <- integer(1_000..9_999),
              nick <- string(:alphanumeric, min_length: 1),
              default <- string(:alphanumeric)
            ) do
        Nickname.set_nick(user_id, group_id, nick)
        assert nick == Nickname.get_nick(user_id, group_id, default)
      end
    end

    test "set_nick overwrites previous value" do
      check all(
              user_id <- integer(1_000_000..9_999_999),
              group_id <- integer(1_000_000..9_999_999),
              first <- string(:alphanumeric, min_length: 1),
              second <- string(:alphanumeric, min_length: 1),
              first != second
            ) do
        Nickname.set_nick(user_id, group_id, first)
        Nickname.set_nick(user_id, group_id, second)
        assert second == Nickname.get_nick(user_id, group_id, "")
      end
    end

    test "rm_nick falls back to default" do
      check all(
              user_id <- integer(10_000_000..99_999_999),
              group_id <- integer(10_000_000..99_999_999),
              nick <- string(:alphanumeric, min_length: 1),
              default <- string(:alphanumeric)
            ) do
        Nickname.set_nick(user_id, group_id, nick)
        Nickname.rm_nick(user_id, group_id)
        assert default == Nickname.get_nick(user_id, group_id, default)
      end
    end
  end
end
