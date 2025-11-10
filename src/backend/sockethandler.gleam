import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option, Some}
import lustre
import lustre/server_component
import mist.{type Connection, type ResponseData}

pub fn serve(
  request: Request(Connection),
  component: lustre.App(start_args, model, msg),
  start_args: start_args,
) -> Response(ResponseData) {
  mist.websocket(
    request:,
    on_init: init_socket(_, component, start_args),
    handler: loop_socket,
    on_close: close_socket,
  )
}

type Socket(msg) {
  Socket(
    component: lustre.Runtime(msg),
    self: Subject(server_component.ClientMessage(msg)),
  )
}

type SocketMessage(msg) =
  server_component.ClientMessage(msg)

type SocketInit(msg) =
  #(Socket(msg), Option(Selector(SocketMessage(msg))))

fn init_socket(
  _,
  component: lustre.App(start_args, model, msg),
  start_args: start_args,
) -> SocketInit(msg) {
  let assert Ok(component) =
    lustre.start_server_component(component, start_args)

  let self = process.new_subject()
  let selector = process.new_selector() |> process.select(self)

  server_component.register_subject(self)
  |> lustre.send(to: component)

  #(Socket(component:, self:), Some(selector))
}

fn loop_socket(
  state: Socket(msg),
  message: mist.WebsocketMessage(SocketMessage(msg)),
  connection: mist.WebsocketConnection,
) -> mist.Next(Socket(msg), SocketMessage(msg)) {
  case message {
    mist.Text(json) -> {
      case json.parse(json, server_component.runtime_message_decoder()) {
        Ok(runtime_message) -> lustre.send(state.component, runtime_message)
        Error(_) -> Nil
      }

      mist.continue(state)
    }

    mist.Binary(_) -> {
      mist.continue(state)
    }

    mist.Custom(client_message) -> {
      let json = server_component.client_message_to_json(client_message)
      let assert Ok(_) = mist.send_text_frame(connection, json.to_string(json))

      mist.continue(state)
    }

    mist.Closed | mist.Shutdown -> {
      server_component.deregister_subject(state.self)
      |> lustre.send(to: state.component)

      mist.stop()
    }
  }
}

fn close_socket(state: Socket(msg)) -> Nil {
  server_component.deregister_subject(state.self)
  |> lustre.send(to: state.component)
}
