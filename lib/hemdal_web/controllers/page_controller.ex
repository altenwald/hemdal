defmodule HemdalWeb.PageController do
  use HemdalWeb, :controller

  alias Hemdal.Check

  def index(conn, _params) do
    render(conn, "index.html", notifications: Check.get_all())
  end
end
