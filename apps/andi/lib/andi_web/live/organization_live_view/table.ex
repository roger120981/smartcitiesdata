defmodule AndiWeb.OrganizationLiveView.Table do
  @moduledoc """
    LiveComponent for organization table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="organizations-index__table">
      <table class="organizations-table">
      <thead>
        <th class="organizations-table__th organizations-table__cell organizations-table__th--sortable organizations-table__th--<%= Map.get(@order, "org_title", "unsorted") %>" phx-click="order-by" phx-value-field="org_title">Organization</th>
        <th class="organizations-table__th organizations-table__cell">Actions</th>
        </thead>

        <%= if @organizations == [] do %>
          <tr><td class="organizations-table__cell" colspan="100%">No Organizations Found!</td></tr>
        <% else %>
          <%= for org <- @organizations do %>
          <tr class="organizations-table__tr">
            <td class="organizations-table__cell organizations-table__cell--break" style="width: 80%;"><%= org["org_title"] %></td>
            <td class="organizations-table__cell organizations-table__cell--break primary-color-link"><%= Link.link("Edit", to: "/organizations/#{org["id"]}", class: "btn") %></td>
          </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
