// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket,
// and connect at the socket path in "lib/web/endpoint.ex".
//
// Pass the token on params as below. Or remove it
// from the params if you are not using authentication.
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/3" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket, _connect_info) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, connect to the socket:
socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("checks:all", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

function show_status(status) {
  switch (status) {
    case "ok": return "OK";
    case "warn": return "WARN";
    case "error": return "FAIL";
  }
}

function status_class(status) {
  switch (status) {
    case "ok": return "sucess";
    case "warn": return "warn";
    case "error": return "danger";
  }
}

channel.on("event", payload => {
  console.log(payload);
  if (!$("#alert-" + payload.alert.id).html()) {
    $("#alerts").append("<tr id='alert-" + payload.alert.id + "'><td class='status'></td><td class='host'></td><td class='description'></td><td class='last-update'></td></tr>")
  }
  $("#alert-" + payload.alert.id).attr("class", status_class(payload.status));
  $("#alert-" + payload.alert.id + " .status").html(show_status(payload.status));
  $("#alert-" + payload.alert.id + " .host").html(payload.alert.host);
  $("#alert-" + payload.alert.id + " .command").html(payload.alert.command);
  if (payload.status == "ok") {
    $("#alert-" + payload.alert.id + " .description").html(payload.result.description);
  } else {
    $("#alert-" + payload.alert.id + " .description").html(payload.result);
  }
  $("#alert-" + payload.alert.id + " .last-update").html(payload.last_update);
});

export default socket
