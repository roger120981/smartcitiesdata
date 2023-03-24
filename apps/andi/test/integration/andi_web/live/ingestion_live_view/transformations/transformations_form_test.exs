defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  import Checkov
  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_attributes: 3,
      get_text: 2,
      get_value: 2,
      get_select: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions

  @url_path "/ingestions/"
  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  setup %{conn: conn} do
    dataset = TDG.create_dataset(%{name: "sample_dataset"})

    transformation1 =
      TDG.create_transformation(%{
        name: "sample",
        type: "concatenation",
        parameters: %{},
        sequence: 1
      })

    transformation2 =
      TDG.create_transformation(%{
        name: "sample2",
        type: "add",
        parameters: %{},
        sequence: 2
      })

    ingestion =
      TDG.create_ingestion(%{
        id: UUID.uuid4(),
        targetDataset: dataset.id,
        name: "sample_ingestion",
        transformations: [transformation1, transformation2]
      })

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

    [view: view, html: html, ingestion: ingestion, conn: conn]
  end

  test "Shows errors for missing name field", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    form_data = %{"name" => ""}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert get_text(html, "##{transformation.id}_transformation_name_error") == "Please enter a valid name."
  end

  test "Header defaults to Transformation when transformation name is cleared from form", %{html: html, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    assert get_text(html, ".transformation-header") =~ "sample"
  end

  test "Shows errors for missing type field", %{view: view, html: html, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    form_data = %{"type" => ""}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert get_text(html, "##{transformation.id}_transformation_type_error") == "Please enter a valid type."
  end

  test "can be expanded and collapsed when clicking the header", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    assert has_element?(view, ".transformation-edit-form--collapsed")

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    assert has_element?(view, ".transformation-edit-form--expanded")

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    assert has_element?(view, ".transformation-edit-form--collapsed")
  end

  test "after selecting type, fields appears", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    assert has_element?(view, "#transformation_#{transformation.id}__sourceFields")
    assert has_element?(view, "#transformation_#{transformation.id}__separator")
    assert has_element?(view, "#transformation_#{transformation.id}__targetField")

    form_data = %{"type" => "add"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert has_element?(view, "#transformation_#{transformation.id}__targetField")
    assert has_element?(view, "#transformation_#{transformation.id}__addends")
  end

  data_test "when selecting #{type}, its respective fields will show", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    assert has_element?(view, "#transformation_#{transformation.id}__sourceFields")
    assert has_element?(view, "#transformation_#{transformation.id}__separator")
    assert has_element?(view, "#transformation_#{transformation.id}__targetField")

    form_data = %{"type" => type}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    for field <- fields do
      assert has_element?(view, "#transformation_#{transformation.id}__#{field}")
    end

    where([
      [:type, :fields],
      ["add", ["addends", "targetField"]],
      ["concatenation", ["sourceFields", "separator", "targetField"]],
      ["constant", ["newValue", "valueType", "targetField"]],
      ["conversion", ["field", "sourceType", "targetType"]],
      ["datetime", ["sourceField", "sourceFormat", "targetField", "targetFormat"]],
      ["division", ["targetField", "dividend", "divisor"]],
      ["multiplication", ["targetField", "multiplicands"]],
      ["regex_extract", ["sourceField", "regex", "targetField"]],
      ["regex_replace", ["sourceField", "regex", "replacement"]],
      ["remove", ["sourceField"]],
      ["subtract", ["targetField", "subtrahends", "minuend"]],
      ["regex_replace", ["sourceField", "regex", "replacement"]]
    ])
  end
end