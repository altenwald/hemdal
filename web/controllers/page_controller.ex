defmodule Heimdall.PageController do
  use Heimdall.Web, :controller

  alias Heimdall.Repo
  alias Heimdall.Notification

  def get_notifications() do
      Application.get_env(:heimdall, :checks, [])
      |> Enum.flat_map(fn({groupkey, checks}) ->
        Enum.flat_map(checks, fn({name, config}) ->
            Enum.map(config[:hosts], fn(host) ->
                groupkey = Atom.to_string(groupkey)
                name = Atom.to_string(name)
                case Notification.find(host, groupkey, name) do
                    %Heimdall.Notification{} = notif ->
                        notif
                    nil ->
                        desc = config[:name]
                        Notification.unknown(host, groupkey, name, desc)
                end
            end)
        end)
      end)
  end

  def index(conn, _params) do
    render conn, "index.html", notifications: get_notifications()
  end

end
