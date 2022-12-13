defmodule AndiWeb.Unit.IngestionLiveView.FinalizeFormTest do
  use ExUnit.Case
  use Placebo

  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.LiveViewTest

  alias AndiWeb.IngestionLiveView.FinalizeForm
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.InputSchemas.FinalizeFormSchema
  alias Phoenix.LiveView

  describe "Immediate cadence selection" do
    test "Fires update_cadence when complete_validation is called with cadence of 'once'", %{} do
      conn = build_conn()

      form_data = %{cadence: "once"}
      ingestion_id = "foo"

      socket = %LiveView.Socket{
        assigns: %{
          ingestion_id: ingestion_id,
          visibility: "hidden"
        },
        parent_pid: conn.owner
      }

      expect(FinalizeFormSchema.changeset_from_form_data(form_data),
        return: %Ecto.Changeset{
          changes: form_data,
          data: %FinalizeFormSchema{},
          types: %{}
        }
      )

      expect(Ingestions.update_cadence(ingestion_id, form_data.cadence), return: nil)

      FinalizeForm.handle_event("validate", %{"form_data" => form_data}, socket)
    end
  end
end