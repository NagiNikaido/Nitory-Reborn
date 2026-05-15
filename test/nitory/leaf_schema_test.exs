defmodule Nitory.Helper.LeafSchemaTest do
  use ExUnit.Case, async: true

  defmodule TestSchema do
    use Nitory.Helper.LeafSchema

    embedded_schema do
      field! :name, :string
      field :age, :integer
      field :kind, Ecto.Enum, values: [:a, :b]
      embeds_one :meta, Meta do
        field :tags, {:array, :string}
      end
    end
  end

  describe "new/2 (cast)" do
    test "valid params with required fields" do
      assert {:ok, %TestSchema{name: "Alice"}} = TestSchema.new(%{"name" => "Alice"})
    end

    test "valid params with all fields" do
      assert {:ok, %TestSchema{name: "Bob", age: 30, kind: :a}} =
               TestSchema.new(%{"name" => "Bob", "age" => 30, "kind" => "a"})
    end

    test "missing required field returns error" do
      assert {:error, _} = TestSchema.new(%{})
    end

    test "returns changeset errors for invalid enum" do
      assert {:error, errors} = TestSchema.new(%{"name" => "C", "kind" => "invalid"})
      assert is_map(errors)
    end
  end

  describe "new!/2" do
    test "raises on invalid input" do
      assert_raise ArgumentError, fn ->
        TestSchema.new!(%{})
      end
    end

    test "returns struct on valid input" do
      assert %TestSchema{name: "D"} = TestSchema.new!(%{"name" => "D"})
    end
  end

  describe "cast/1" do
    test "same as new/2" do
      assert TestSchema.cast(%{"name" => "E"}) == TestSchema.new(%{"name" => "E"})
    end
  end

  describe "dump/1" do
    test "dumps to json-compatible map" do
      schema = TestSchema.new!(%{"name" => "F", "kind" => "b"})
      assert %{name: "F", kind: :b} = TestSchema.dump(schema)
    end

    test "dumps embedded schema" do
      schema = TestSchema.new!(%{"name" => "G", "meta" => %{"tags" => ["x", "y"]}})
      assert %{name: "G", meta: %{tags: ["x", "y"]}} = TestSchema.dump(schema)
    end
  end
end