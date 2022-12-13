defmodule AndiWeb.Unit.IngestionLiveView.MetadataFormTest do
  use ExUnit.Case
  use Placebo

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.IngestionLiveView.FormUpdate
  alias AndiWeb.IngestionLiveView.MetadataForm
  alias Andi.InputSchemas.Datasets

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoint AndiWeb.Endpoint

  setup do
    allow FormUpdate.send_value(any(), any()), return: {:ok}
    :ok
  end

  describe "name field" do
    test "can be updated" do
      ingestion = create_ingestion(%{name: "Original"})
      allow Ingestions.get(ingestion.id), return: ingestion
      allow Ingestions.update(ingestion, %{name: "Updated"}), return: {:ok, ingestion}
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      form_data = %{"name" => "Updated"}
      form = element(view, "#ingestion_metadata_form")
      render_change(form, %{"form_data" => form_data})

      AndiWeb.Endpoint.broadcast("form-save", "save-all", %{ingestion_id: ingestion.id})

      eventually(fn ->
        assert_called Ingestions.update(ingestion, %{name: "Updated"})
      end)
    end

    test "shows an error if blank" do
      ingestion = create_ingestion(%{})
      form_data = %{"name" => ""}
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      render_change(view, "validate", %{"form_data" => form_data})

      error = element(view, "#name-error-msg", "Please enter a valid name.") |> render()
      refute error == nil
    end
  end

  describe "source format" do
    test "can be updated" do
      ingestion = create_ingestion(%{sourceFormat: "text/xml"})
      allow Ingestions.get(ingestion.id), return: ingestion
      allow Ingestions.update(ingestion, any()), return: {:ok, ingestion}
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      form_data = %{"sourceFormat" => "application/gtfs+protobuf"}
      form = element(view, "#ingestion_metadata_form")
      render_change(form, %{"form_data" => form_data})

      AndiWeb.Endpoint.broadcast("form-save", "save-all", %{ingestion_id: ingestion.id})

      eventually(fn ->
        assert_called Ingestions.update(ingestion, %{sourceFormat: "application/gtfs+protobuf"})
      end)
    end

    test "shows an error if blank" do
      ingestion = create_ingestion(%{})
      form_data = %{"sourceFormat" => ""}
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      render_change(view, "validate", %{"form_data" => form_data})

      error = element(view, "#sourceFormat-error-msg", "Please enter a valid source format.") |> render()
      refute error == nil
    end
  end

  describe "selected dataset" do
    test "button opens select dataset modal" do
      ingestion = create_ingestion(%{})
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}
      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})
      assert element(view, ".manage-datasets-modal--hidden") |> has_element?

      view |> find_select_dataset_btn() |> render_click()
      assert element(view, ".manage-datasets-modal--visible") |> has_element?
    end

    test "form can be updated" do
      ingestion = create_ingestion(%{})
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}
      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})
      assert element(view, ".manage-datasets-modal--hidden") |> has_element?

      view |> find_select_dataset_btn() |> render_click()
    end

    test "shows an error if blank" do
      ingestion = create_ingestion(%{})
      form_data = %{"targetDatasetName" => ""}
      allow Datasets.get(any()), return: nil

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      render_change(view, "validate", %{"form_data" => form_data})

      error = element(view, "#targetDataset-error-msg", "Please enter a valid target dataset.") |> render()
      refute error == nil
    end

    test "shows an error if there is a target dataset that does not exist in the database" do
      ingestion = create_ingestion(%{})
      form_data = %{"targetDataset" => "id_of_deleted_dataset"}
      allow Datasets.get(any()), return: nil

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      render_change(view, "validate", %{"form_data" => form_data})

      error =
        element(view, "#targetDataset-error-msg", "Dataset with id: id_of_deleted_dataset does not exist. It may have been deleted.")
        |> render()

      refute error == nil
    end
  end

  describe "after successful save" do
    test "notify if no missing fields" do
      ingestion = create_ingestion(%{name: "Validity Is Great"})
      allow Ingestions.get(ingestion.id), return: ingestion
      allow Ingestions.update(any(), any()), return: {:ok, ingestion}
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      AndiWeb.Endpoint.broadcast("form-save", "save-all", %{ingestion_id: ingestion.id})

      eventually(fn ->
        assert_called FormUpdate.send_value(any(), {:update_save_message, "valid"})
      end)
    end

    test "notify if required fields missing" do
      ingestion = create_ingestion(%{name: ""})
      allow Ingestions.get(ingestion.id), return: ingestion
      allow Ingestions.update(any(), any()), return: {:error, %Ecto.Changeset{errors: [name: {"is required", []}]}}
      allow Datasets.get(any()), return: %{business: %{dataTitle: "Dataset Name"}}

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      AndiWeb.Endpoint.broadcast("form-save", "save-all", %{ingestion_id: ingestion.id})

      eventually(fn ->
        assert_called FormUpdate.send_value(any(), {:update_save_message, "invalid"})
      end)
    end
  end

  defp find_select_dataset_btn(view) do
    element(view, ".btn", "Select Dataset")
  end

  def create_ingestion(overrides) do
    ingestion = TDG.create_ingestion(overrides) |> Map.put(:submissionStatus, :draft)
  end
end