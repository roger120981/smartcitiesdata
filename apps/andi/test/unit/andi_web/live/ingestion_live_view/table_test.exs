defmodule AndiWeb.IngestionLiveView.TableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions"
  @user UserHelpers.create_user()

  defp allowAuthUser do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
  end

  setup do
    allowAuthUser()
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "Basic ingestions page load" do
    test "shows \"No Ingestions\" when there are no rows to show", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [])
      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "No Ingestions"
    end

    test "shows ingestions when there are rows to show and the dataset title is nil", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [%{name: "penny", id: "123"}])
      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "penny"
    end

    test "shows ingestions when there are rows to show and the dataset title not nil", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [%{name: "penny", id: "123", dataset: %{business: %{dataTitle: "Hazel"}}}])
      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "penny"
      assert get_text(html, ".ingestions-table__cell") =~ "Hazel"
    end
  end
end