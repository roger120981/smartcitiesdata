defmodule AndiWeb.IngestionLiveView.MetadataFormTest do
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
      get_attributes: 3,
      get_text: 2,
      get_value: 2,
      get_select: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.FinalizeFormSchema

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "ingestions metadata form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDataset: dataset.id, name: "sample_ingestion"})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [ingestion: ingestion, view: view, html: html, dataset: dataset, conn: conn]
    end

    test "name field defaults to it's existing name", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      assert get_value(html, "#ingestion_metadata_form_name") == ingestion.name
    end

    test "name field can be altered and saved", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      new_name = "new_name"

      form_data = %{
        "name" => new_name
      }

      metadata_view = find_live_child(view, "ingestion_metadata_form_editor")
      render_change(metadata_view, "validate", %{"form_data" => form_data})
      render_change(view, "save")

      html = render(view)
      assert get_value(html, "#ingestion_metadata_form_name") == new_name
    end

    test "dataset name field defaults to it's existing association", %{
      view: view,
      html: html,
      ingestion: ingestion,
      dataset: dataset
    } do
      assert get_value(html, "#ingestion_metadata_form_targetDatasetName") == dataset.business.dataTitle
    end

    test "source format field defaults to its existing value", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      current_select_value = get_select(html, "#ingestion_metadata_form_sourceFormat") |> Tuple.to_list()
      assert ingestion.sourceFormat in current_select_value
    end

    test "source format field can be altered and saved", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      new_source_format = "text/xml"

      form_data = %{
        "sourceFormat" => new_source_format
      }

      metadata_view = find_live_child(view, "ingestion_metadata_form_editor")
      render_change(metadata_view, "validate", %{"form_data" => form_data})
      render_change(view, "save")

      html = render(view)
      current_select_value = get_select(html, "#ingestion_metadata_form_sourceFormat") |> Tuple.to_list()

      assert new_source_format in current_select_value
    end

    # todo: ticket #757 will fullfil this test
    @tag :skip
    test "can not edit source format for published ingestion", %{
      view: view,
      html: html,
      ingestion: ingestion,
      conn: conn
    } do
      {:ok, dataset} =
        TDG.create_dataset(%{name: "sample_dataset", submissionStatus: :published})
        |> Datasets.update()

      eventually(fn ->
        andi_dataset = Datasets.get(dataset.id)
        assert andi_dataset.id == dataset.id
      end)

      {:ok, ingestion} =
        TDG.create_ingestion(%{targetDataset: dataset.id, submissionStatus: :published})
        |> Ingestions.update()

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      refute Enum.empty?(get_attributes(html, ".ingestion-metadata-form__format select", "disabled"))
    end
  end

  # todo: ticket #757 will fullfil this test
  @tag :skip
  test "topLevelSelector is read only when sourceFormat is not xml nor json", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})
    {:ok, dataset} = Datasets.update(smrt_dataset)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    refute Enum.empty?(get_attributes(html, "#form_data_topLevelSelector", "readonly"))
  end

  defp find_select_dataset_btn(view) do
    element(view, ".btn", "Select Dataset")
  end
end