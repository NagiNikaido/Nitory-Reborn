defmodule Nitory.MessageSegmentTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

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
      assert {:ok, %Segment.At{data: %{qq: 12_345}}} =
               Segment.cast(%{"type" => "at", "data" => %{"qq" => 12_345}})
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

  describe "doctests" do
    doctest Nitory.Message.Segment.Text
    doctest Nitory.Message.Segment.Image
    doctest Nitory.Message.Segment.At
    doctest Nitory.Message.Segment.Reply
  end

  describe "property-based tests" do
    test "Text cast + dump roundtrips" do
      check all(
              text <- StreamData.string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, seg} = Segment.Text.cast(%{"type" => "text", "data" => %{"text" => text}})
        assert %{type: :text, data: %{text: ^text}} = Nitory.Helper.LeafSchema.dump(seg)
      end
    end

    test "Image cast + dump roundtrips" do
      check all(
              file <- StreamData.string(:alphanumeric, min_length: 1),
              url <- StreamData.string(:alphanumeric),
              sub_type <- StreamData.member_of([0, 1])
            ) do
        assert {:ok, seg} = Segment.Image.cast(%{
          "type" => "image",
          "data" => %{"file" => file, "url" => url, "sub_type" => sub_type}
        })
        dump = Nitory.Helper.LeafSchema.dump(seg)
        assert dump.data.file == file
      end
    end

    test "At cast + dump roundtrips" do
      check all(
              qq <- StreamData.one_of([StreamData.integer(100_000..9_999_999), StreamData.constant("all")]),
              name <- StreamData.string(:alphanumeric)
            ) do
        assert {:ok, seg} = Segment.At.cast(%{
          "type" => "at",
          "data" => %{"qq" => qq, "name" => name}
        })
        dump = Nitory.Helper.LeafSchema.dump(seg)
        assert dump.data.qq == qq
      end
    end

    test "Reply cast + dump roundtrips" do
      check all(
              id <- StreamData.string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, seg} = Segment.Reply.cast(%{
          "type" => "reply",
          "data" => %{"id" => id}
        })
        assert %{type: :reply, data: %{id: ^id}} = Nitory.Helper.LeafSchema.dump(seg)
      end
    end
  end
end
