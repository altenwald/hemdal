defmodule Heimdall.Notification do
    use Heimdall.Web, :model
    import Ecto.Query
    alias Heimdall.Repo

    schema "notifications" do
        field :hostname, :string
        field :groupkey, :string
        field :name, :string
        field :description, :string
        field :status_text, :string
        field :status, :integer
        field :status_class, :string, virtual: true

        timestamps()
    end

    @required_fields ~w(hostname groupkey name status_text status)
    @optional_fiels ~w(description)

    def find(hostname, groupkey, name) do
        Repo.one(
            from p in Heimdall.Notification,
            select: p,
            where: p.hostname == ^hostname and
                   p.groupkey == ^groupkey and
                   p.name == ^name,
            order_by: [desc: p.inserted_at],
            limit: 1)
        |> status_class
    end

    def remove_old() do
        Repo.delete_all(
            from p in Heimdall.Notification,
            where: p.inserted_at <= datetime_add(^Ecto.DateTime.utc, -6, "hour")
        )
    end

    def status_class(nil), do: nil
    def status_class(notif) do
        %Heimdall.Notification{notif | status_class: case notif.status do
            0 -> "default"
            1 -> "warning"
            256 -> "active"
            _ -> "danger"
        end}
    end

    def unknown(hostname, groupkey, name, description) do
        %Heimdall.Notification{
          hostname: hostname, groupkey: groupkey, name: name,
          description: description, status_text: "UNKNOWN",
          status: 256, status_class: "active"}
    end

    def changeset(model, params \\ %{}) do
        model
        |> cast(params, @required_fields, @optional_fiels)
    end
end
