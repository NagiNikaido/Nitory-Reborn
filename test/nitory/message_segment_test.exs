defmodule Nitory.MessageSegmentTest do
  use ExUnit.Case, async: true

  alias Nitory.Message
  alias Nitory.Message.Segment

  describe "Segment.Text" do
    test "casts string-keyed map" do
      assert {:ok, %Segment.Text{type: :text, data: %{text: "hello"}}} =
               Segment.cast(%{"type" => "text", "data" => %{"text" => "hello"}})
    end

    test "casts atom-keyed map" do
      assert {:ok, %Segment.Text{type: :text, data: %{text: "world"}}} =
               Segment.cast(%{type: :text, data: %{text: "world"}})
    end

    test "rejects invalid segment type" do
      assert {:error, _} = Segment.cast(%{"type" => "unknown", "data" => %{}})
    end

    test "dumps segment back to map" do
      segment = Segment.Text.new!(%{data: %{text: "hi"}})
      assert {:ok, %{type: :text, data: %{text: "hi"}}} = Segment.dump(segment)
    end
  end

  describe "Segment.Image" do
    test "casts image segment with file" do
      assert {:ok, %Segment.Image{data: %{file: "img.png"}}} =
               Segment.cast(%{"type" => "image", "data" => %{"file" => "img.png"}})
    end

    test "casts image segment with all fields" do
      result =
        Segment.cast(%{
          "type" => "image",
          "data" => %{"file" => "img.png", "url" => "http://ex.com/img.png", "sub_type" => 1}
        })

      assert {:ok,
              %Segment.Image{
                data: %{file: "img.png", url: "http://ex.com/img.png", sub_type: :custom}
              }} = result
    end
  end

  describe "Segment.At" do
    test "casts at segment with integer qq" do
      assert {:ok, %Segment.At{data: %{qq: 12345}}} =
               Segment.cast(%{"type" => "at", "data" => %{"qq" => 12345}})
    end

    test "casts at segment with string qq" do
      assert {:ok, %Segment.At{data: %{qq: "all"}}} =
               Segment.cast(%{"type" => "at", "data" => %{"qq" => "all"}})
    end
  end

  describe "Segment.Reply" do
    test "casts reply segment" do
      assert {:ok, %Segment.Reply{data: %{id: "123"}}} =
               Segment.cast(%{"type" => "reply", "data" => %{"id" => "123"}})
    end
  end

  describe "Message.cast/1" do
    test "accepts raw string" do
      assert {:ok, "hello"} = Message.cast("hello")
    end

    test "accepts list of segment maps" do
      segments = [
        %{"type" => "text", "data" => %{"text" => "hi"}},
        %{"type" => "at", "data" => %{"qq" => 123}}
      ]

      assert {:ok, [%Segment.Text{}, %Segment.At{}]} = Message.cast(segments)
    end

    test "rejects invalid segment list" do
      assert {:error, _} = Message.cast([%{"type" => "unknown", "data" => %{}}])
    end

    test "rejects unsupported type" do
      assert {:error, _} = Message.cast(42)
    end
  end

  describe "Message.dump/1" do
    test "dumps string unchanged" do
      assert {:ok, "hello"} = Message.dump("hello")
    end

    test "dumps segment list" do
      segments = [Segment.Text.new!(%{data: %{text: "hi"}})]
      assert {:ok, [%{type: :text, data: %{text: "hi"}}]} = Message.dump(segments)
    end
  end
end