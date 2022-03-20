defmodule Andi.InputSchemas.Ingestion.IngestionTest do
  use ExUnit.Case
  import Checkov
  use Placebo

  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Datasets

  @ingestion_id Ecto.UUID.generate()
  @dataset_id Ecto.UUID.generate()

  @valid_changes %{
    id: @ingestion_id,
    name: "Name",
    targetDataset: @dataset_id,
    cadence: "never",
    extractSteps: [%{type: "http", context: %{action: "GET", url: "example.com"}}],
    schema: [
      %{id: Ecto.UUID.generate(), name: "name", type: "type", bread_crumb: "name", dataset_id: "id", selector: "/cam/cam"}
    ],
    sourceFormat: "sourceFormat"
  }

  describe "changeset" do
    data_test "requires value for #{inspect(field)}" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}
      changes = Map.delete(@valid_changes, field)

      changeset = Ingestion.changeset(changes)

      refute changeset.valid?

      errors = accumulate_errors(changeset)
      {:ok, actual_error} = Map.fetch(errors, field)
      assert actual_error == [{field, {"is required", [validation: :required]}}]

      where([
        [:field],
        [:cadence],
        [:sourceFormat],
        [:targetDataset],
        [:name]
      ])
    end

    test "sourceFormat must be valid for source type ingest and stream" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      changes =
        @valid_changes
        |> put_in([:sourceFormat], "kml")

      changeset = Ingestion.changeset(changes)

      refute changeset.valid?

      assert accumulate_errors(changeset) ==
               %{
                 sourceFormat: [{:sourceFormat, {"invalid format for ingestion", []}}]
               }
    end

    data_test "topLevelSelector is required when sourceFormat is #{source_format}" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      changes = @valid_changes |> put_in([:sourceFormat], source_format)

      changeset = Ingestion.changeset(changes)

      refute changeset.valid?

      assert accumulate_errors(changeset) == %{
               topLevelSelector: [{:topLevelSelector, {"is required", [validation: :required]}}]
             }

      where(source_format: ["text/xml"])
    end

    data_test "validates the schema appropriately when sourceType is #{source_type} and schema is #{inspect(schema)}" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: source_type}}

      changes =
        @valid_changes
        |> put_in([:schema], schema)
        |> put_in([:sourceType], source_type)

      changeset = Ingestion.changeset(changes)

      assert changeset.valid? == false

      error_tuple =
        case message_type do
          :required ->
            {"is required", [validation: :assoc, type: {:array, :map}]}

          :not_empty ->
            {"cannot be empty", []}
        end

      errors = accumulate_errors(changeset)

      assert {:schema, error_tuple} in errors.schema

      where(
        source_type: ["ingest", "stream", "ingest"],
        message_type: [:required, :required, :not_empty],
        schema: [nil, nil, []]
      )
    end

    test "xml source format requires all fields in the schema to have selectors" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      schema = [
        %{name: "field_name", type: "string"},
        %{name: "other_field", type: "string", selector: "this is the only selector"},
        %{name: "another_field", type: "integer", selector: ""}
      ]

      changes =
        @valid_changes
        |> Map.merge(%{
          cadence: "never",
          extractSteps: [%{type: "http", context: %{action: "GET", url: "example.com"}}],
          schema: schema,
          sourceFormat: "text/xml",
          topLevelSelector: "whatever"
        })

      changeset = Ingestion.changeset(changes)

      refute changeset.valid?
      assert length(changeset.errors) == 2

      assert changeset.errors
             |> Enum.any?(fn {:schema, {error, _}} -> String.match?(error, ~r/selector.+field_name/) end)

      assert changeset.errors
             |> Enum.any?(fn {:schema, {error, _}} -> String.match?(error, ~r/selector.+another_field/) end)
    end

    data_test "given a dataset with a schema that has #{field}, format is defaulted to #{expected_format}" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      changes = @valid_changes |> put_in([:schema], [%{name: "datefield", type: field, dataset_id: "123", bread_crumb: "thing"}])

      changeset = Ingestion.changeset(changes)

      first_schema_field = changeset.changes.schema |> hd()

      assert first_schema_field.changes.format == expected_format

      where([[:field, :expected_format], ["date", "{ISOdate}"], ["timestamp", "{ISO:Extended}"]])
    end

    data_test "invalid formats are rejected for #{field} schema fields" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      changes =
        @valid_changes
        |> put_in([:schema], [%{name: "datefield", type: field, dataset_id: "123", bread_crumb: "thing", format: "123"}])

      changeset = Ingestion.changeset(changes)

      first_schema_field = changeset.changes.schema |> hd()

      assert {:format, {"Invalid format string, must contain at least one directive.", []}} in first_schema_field.errors

      refute changeset.valid?

      where(field: ["date", "timestamp"])
    end

    data_test "valid formats are accepted for #{field} schema fields" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      changes =
        @valid_changes
        |> put_in([:schema], [%{name: "datefield", type: field, dataset_id: "123", bread_crumb: "thing", format: format}])
        |> Map.merge(%{
          sourceFormat: "text/csv"
        })

      changeset = Ingestion.changeset(changes)

      assert changeset.valid?

      where([
        [:field, :format],
        ["date", "{YYYY}{0M}{0D}"],
        ["timestamp", "{ISO:Extended}"]
      ])
    end

    data_test "cadence should be valid: #{inspect(cadence_under_test)}" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      changes =
        @valid_changes
        |> put_in([:cadence], cadence_under_test)
        |> Map.merge(%{
          sourceFormat: "text/csv"
        })

      changeset = Ingestion.changeset(changes)

      assert %{} == accumulate_errors(changeset)
      assert changeset.valid?

      where([
        [:cadence_under_test],
        ["once"],
        ["never"],
        ["1 2 3 4 5"],
        ["1 2 3 4 5 6"],
        ["*/10 * * * * *"],
        ["*/2 * * * * *"]
      ])
    end

    data_test "cadence should not be valid: #{inspect(cadence_under_test)}" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      changes =
        @valid_changes
        |> put_in([:cadence], cadence_under_test)
        |> Map.merge(%{
          sourceFormat: "text/csv"
        })

      changeset = Ingestion.changeset(changes)

      refute changeset.valid?
      refute Enum.empty?(accumulate_errors(changeset))

      where([
        [:cadence_under_test],
        ["* * * * * *"],
        ["*/1 * * * * *"],
        ["a b c d e f"]
      ])
    end

    test "extract steps are valid when http step is last" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      extract_steps = [
        %{type: "secret", context: %{destination: "bob_field", key: "one", sub_key: "secret-key"}},
        %{type: "http", context: %{action: "GET", url: "example.com"}}
      ]

      changes =
        @valid_changes
        |> put_in([:extractSteps], extract_steps)
        |> Map.merge(%{
          sourceFormat: "text/csv"
        })

      changeset = Ingestion.changeset(changes)

      assert %{} == accumulate_errors(changeset)
      assert changeset.valid?
    end

    test "extract steps are valid when s3 step is last" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      extract_steps = [
        %{type: "secret", context: %{destination: "bob_field", key: "one", sub_key: "secret-key"}},
        %{type: "s3", context: %{url: "something"}}
      ]

      changes =
        @valid_changes
        |> put_in([:extractSteps], extract_steps)
        |> Map.merge(%{
          sourceFormat: "text/csv"
        })

      changeset = Ingestion.changeset(changes)

      assert %{} == accumulate_errors(changeset)
      assert changeset.valid?
    end

    test "extract steps are not valid when http or s3 step is not last" do
      allow Datasets.get(any()), return: %{technical: %{sourceType: "ingest"}}

      extract_steps = [
        %{type: "s3", context: %{url: "something"}},
        %{type: "http", context: %{action: "GET", url: "example.com"}},
        %{type: "secret", context: %{destination: "bob_field", key: "one", sub_key: "secret-key"}}
      ]

      changes =
        @valid_changes
        |> put_in([:extractSteps], extract_steps)
        |> Map.merge(%{
          sourceFormat: "text/csv"
        })

      changeset = Ingestion.changeset(changes)

      expected_error = %{extractSteps: [extractSteps: {"cannot be empty and must end with a http or s3 step", []}]}
      assert expected_error == accumulate_errors(changeset)
      refute changeset.valid?
    end
  end

  defp accumulate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn _changeset, field, {msg, opts} ->
      {field, {msg, opts}}
    end)
  end

  defp delete_in(data, path) do
    pop_in(data, path) |> elem(1)
  end
end