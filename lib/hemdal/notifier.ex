defmodule Hemdal.Notifier do
  @moduledoc """
  Notifier implements the base for a notification system which will send
  the event or information message to an external service like Slack,
  Mattermost, Mailgun, Sendblue, or whatever else provider.

  The notifier implementation must define the `send/3` callback ensuring
  the sending of the information is being able. The official notifiers
  supported and implemented by Hemdal are:

  - `Hemdal.Notifier.Slack` which implements the sending of the Slack
    message avoiding implement the optional callbacks.
  - `Hemdal.Notifier.Mattermost` which implements the sending of the
    Mattermost message and in the same way avoid implement the optional
    callbacks because are compatible with Slack.
  - `Hemdal.Notifier.Mock` is an implementation which makes easier the
    implementation of tests.

  ## Implement a new Notifier

  The requirements are not too many, you only need to create a module
  in your project with the name `Hemdal.Notifier.XXX` changing the `XXX`
  with the name you want to implement. For example, if you have a
  specific system via TCP created to notify in your installation, if
  you give to that system the name of _mercury_, you can create a module
  in the implementation of the alert system called `Hemdal.Notifier.Mercury`
  and then:

  ```elixir
  defmodule Hemdal.Notifier.Mercury do
    use Hemdal.Notifier

    @impl Hemdal.Notifier
    def send(message, token, metadata) do
      # do your stuff
    end
  end
  ```

  The return of `send/3` isn't going to be in use, you can return whatever.
  """

  @default_channel "#alerts"
  @default_username "Hemdal"
  @default_icon ":rotating_light:"
  @default_desc "<no description>"

  @typedoc """
  The possible status processed by the messages.
  """
  @type status() :: :ok | :warn | :error | :disabled | String.t()

  defp to_text(:ok), do: "OK"
  defp to_text(:warn), do: "WARN"
  defp to_text(:error), do: "FAIL"
  defp to_text(:disabled), do: "OFF"
  defp to_text(_), do: "UNKNOWN"

  defp to_color(:ok), do: "#009900"
  defp to_color(:warn), do: "#FFDA55"
  defp to_color(:error), do: "#990000"
  defp to_color(:disabled), do: "#888888"
  defp to_color(_), do: "#444444"

  defp get_msg(alert, _duration, :disabled, _) do
    "disabled #{alert.name} on #{alert.host.name}"
  end

  defp get_msg(alert, _duration, :ok, :ok) do
    "sucessful run #{alert.name} on #{alert.host.name}"
  end

  defp get_msg(alert, duration, :ok, :warn) do
    "sucessful again run #{alert.name} on #{alert.host.name} after #{duration} sec"
  end

  defp get_msg(alert, duration, :ok, :error) do
    "recovered run #{alert.name} on #{alert.host.name} after #{duration} sec"
  end

  defp get_msg(alert, _duration, :warn, :ok) do
    "start to fail #{alert.name} on #{alert.host.name}"
  end

  defp get_msg(alert, duration, :warn, :warn) do
    "failing #{alert.name} on #{alert.host.name} lasting #{duration} sec"
  end

  defp get_msg(alert, duration, :error, :warn) do
    "broken #{alert.name} on #{alert.host.name} lasting #{duration} sec"
  end

  defp get_msg(alert, duration, :error, :error) do
    "still broken #{alert.name} on #{alert.host.name} lasting #{duration} sec"
  end

  @doc """
  Send the message using the notifier module, the status of the event,
  the previous status, the alert information (see `Hemdal.Config.Alert`),
  metadata and duration from the previous status to the current one.

  The first parameter is the notifier data, see `Hemdal.Config.Notifier`
  for further information.

  The status could be an atom:

  - `:ok` for the success state
  - `:warn` when it's starting to fail
  - `:error` for the failure state
  - `:disabled` when the alert is disabled

  The previous state could be `nil` if there is no previous state.

  The metadata is a map which could contains the following keys as strings:

  - `"message"` for a description of the error, default: `"<no description>"`
  - `"status"` for the notification of the _Incoming Status_ or the status
    which is provided from the alert.

  The duration could be `nil` if there is no previous state or if from the
  previous state was not expected to have a counting of the duration.
  """
  @spec send(
          Hemdal.Config.Notifier.t(),
          status(),
          status(),
          Hemdal.Config.Alert.t(),
          metadata(),
          duration()
        ) :: :ok
  def send(notifier, status, prev, alert, metadata, duration) do
    notifier_mod = Module.concat([__MODULE__, notifier.type])
    desc = metadata["message"] || @default_desc
    channel = notifier.metadata["channel"] || @default_channel
    username = notifier.username || @default_username
    icon = notifier.metadata["icon"] || @default_icon

    fields = [
      notifier_mod.field("Host Name", alert.host.name),
      notifier_mod.field("Command Name", alert.command.name),
      notifier_mod.field("Description", desc, false),
      notifier_mod.field("Status", to_text(status)),
      notifier_mod.field("Prev. Status", to_text(prev)),
      notifier_mod.field("Duration", "#{duration} sec"),
      notifier_mod.field("Incoming Status", metadata["status"])
    ]

    atts = [notifier_mod.attach(alert.name, to_color(status), fields)]

    message = %{
      "text" => get_msg(alert, duration, status, prev),
      "username" => username,
      "icon_emoji" => icon,
      "channel" => channel,
      "attachments" => atts
    }

    notifier_mod.send(message, notifier.token, notifier.metadata)
    :ok
  end

  @typedoc """
  The message is a data map where we can define different keys. The
  information (defined in `send/6`) is as follows:

  - `text` the text message to be sent
  - `username` provided by the notifier data, default: "Hemdal"
  - `icon_emoji` provided by the notifier metadata information,
    default: ":rotating_light:"
  - `channel` provided by the notifier metadata, default: "#alerts"
  - `attachments` is a list of attachments provided by the
    `attach/3` callback implemented in the notifier.
  """
  @type message() :: %{String.t() => any()}

  @typedoc """
  The token is provided from the notifier structure, see
  `Hemdal.Config.Notifier` for further information.
  """
  @type token() :: String.t()

  @typedoc """
  The metadata is provided by the notifier structure, see
  `Hemdal.Config.Notifier` for further information.
  """
  @type metadata() :: %{atom() => any()} | Keyword.t()

  @typedoc """
  The duration from previous status to the new one.
  """
  @type duration() :: nil | pos_integer()

  @doc """
  Callback for `send/3`. It must implement the necessary backend to send the
  message for the backend implementation. The information passed is the
  message formatted as a map, see `message/0` type for further information.

  The token must be the information needed for the system to be authenticated
  or recognised to send the message.

  Finally, the metadata must be information to be used as extra information
  inside of the map to be useful for the backend. See `metadata/0` type for
  further information.
  """
  @callback send(message(), token(), metadata()) :: any()

  @typedoc """
  The field name is the name of the field which we provide from the sending
  of the message. We have defined the name of the fields and they are:

  - Host Name, based on the alert host name
  - Command Name, based on the alert command name
  - Description, description from metadata if any
  - Status, the new state
  - Prev. Status, the previous state
  - Duration, the duration from previous to current state
  - Incoming Status, the received status from the check
  """
  @type field_name() :: String.t()

  @typedoc """
  The field value is the content which should be shown as the value. It must
  be a string because finally all of the data will be represented as text.
  """
  @type field_value() :: String.t()

  @typedoc """
  Is it a short field? It is determined mainly for Slack, Mattermost, and
  similar systems where we can include short fields in the way they could
  appear two fields in the same line if both are short.
  """
  @type short?() :: boolean()

  @typedoc """
  The field map representation of the field. It will be dependent of the
  notifier backend which should determine what's the format desired for
  the field.
  """
  @type field() :: map()

  @doc """
  Creates a field representation in a map. See `field/0` type for further
  information. It provides a field name and value which will be included
  inside of the field map returned. The return format finally will be
  determined by the implementation.
  """
  @callback field(field_name(), field_value()) :: field()

  @doc """
  Creates a field representation in a map. See `field/0` type for further
  information. In addition to the field name and value it's receiving if
  the field is short or not. It's put in this way to place two fields in
  the same line (horizontally) if both are short.
  """
  @callback field(field_name(), field_value(), short?()) :: field()

  @typedoc """
  The name of the attachment.
  """
  @type attach_name() :: String.t()

  @typedoc """
  The color provided for the attachment. The color is provided usually in
  the format `#rrggbb` where we are providing a value from 00-ff for each
  color to create the RGB (red, green, and blue) combination.
  """
  @type attach_color() :: String.t()

  @typedoc """
  The list of the fields attached.
  """
  @type attach_fields() :: [field()]

  @typedoc """
  The URL for a custom image to be included inside of the attachment.
  """
  @type img_url() :: String.t()

  @doc """
  The attach callback which should return the map according to the information
  attached. The attachment is usually created with the accumulation of the fields
  inside.
  """
  @callback attach(attach_name, attach_color, attach_fields) :: map()

  @doc """
  Same as `attach/3` but let specify the `img_url` field for adding a custom
  image to the message.
  """
  @callback attach(attach_name, attach_color, attach_fields, img_url) :: map()

  @doc false
  def attach(title, color, fields, img_url \\ "") do
    %{"title" => title, "color" => color, "fields" => fields, "img_url" => img_url}
  end

  @doc false
  def field(title, value, short? \\ true) do
    %{"title" => title, "value" => value, "short" => short?}
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Hemdal.Notifier

      @impl Hemdal.Notifier
      defdelegate attach(title, color, fields, image_url \\ ""), to: Hemdal.Notifier

      @impl Hemdal.Notifier
      defdelegate field(title, value, short? \\ true), to: Hemdal.Notifier

      defoverridable attach: 3,
                     attach: 4,
                     field: 2,
                     field: 3
    end
  end
end
