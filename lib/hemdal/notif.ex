defmodule Hemdal.Notif do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.AlertNotif

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "notifs" do
    field :metadata, :map
    field :token, :string
    field :type, :string
    field :username, :string

    has_many :alert_notifs, AlertNotif
    timestamps()
  end

  @doc false
  def changeset(notif, attrs) do
    notif
    |> cast(attrs, [:token, :username, :type, :metadata])
    |> validate_required([:token, :username, :type, :metadata])
  end
end
