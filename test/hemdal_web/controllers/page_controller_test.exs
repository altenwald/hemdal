defmodule HemdalWeb.PageControllerTest do
  use HemdalWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Hemdal Alerts/Alarms Panel"
  end
end
