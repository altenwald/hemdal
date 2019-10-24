defmodule Hemdal do
  @moduledoc """
  Hemdal keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def reload_all do
    Hemdal.Host.Conn.reload_all
    Hemdal.Check.reload_all
  end
end
