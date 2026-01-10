flint_without_parens = [
  deftype: 2,
  field!: 1,
  field!: 2,
  field!: 3,
  field: 1,
  field: 2,
  field: 3,
  embeds_one!: 2,
  embeds_one!: 3,
  embeds_one!: 4,
  embeds_one: 2,
  embeds_one: 3,
  embeds_one: 4,
  embeds_many!: 2,
  embeds_many!: 3,
  embeds_many!: 4,
  embeds_many: 2,
  embeds_many: 3,
  embeds_many: 4
]

[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  locals_without_parens: flint_without_parens,
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/*/seeds.exs"]
]
