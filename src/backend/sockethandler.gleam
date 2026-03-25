import gleam/bytes_tree
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import lustre
import lustre/server_component
import mist.{type Connection, type ResponseData}
import shared/message

pub fn serve(
  request: Request(Connection),
  component: lustre.App(start_args, model, msg),
  id: String,
  actor: actor.Started(Subject(message.RoomControl(start_args))),
) -> Response(ResponseData) {
  let start_args = actor.call(actor.data, 1000, message.FetchRoom(id, _))
  case start_args {
    Some(start_args) ->
      mist.websocket(
        request:,
        on_init: init_socket(_, component, start_args),
        handler: loop_socket,
        on_close: close_socket,
      )
    None ->
      response.new(404)
      |> response.set_body(
        bytes_tree.from_string("Requested resource not found") |> mist.Bytes,
      )
  }
}

pub fn serve_slow(
  request: Request(Connection),
  component: lustre.App(
    #(List(#(Int, String)), start_args),
    model,
    msg,
  ),
  id: String,
  roomhandler: actor.Started(Subject(message.RoomControl(start_args))),
  statehandler: actor.Started(Subject(message.StateControl)),
) -> Response(ResponseData) {
  let start_args_opt = actor.call(roomhandler.data, 1000, message.FetchRoom(id, _))
  let answer_list = actor.call(statehandler.data, 1000, message.FetchQuestions(_))

  case start_args_opt {
    Some(start_args) ->
      mist.websocket(
        request:,
        on_init: init_socket(_, component, #(answer_list,start_args)),
        handler: loop_socket,
        on_close: close_socket,
      )
    None ->
      response.new(404)
      |> response.set_body(
        bytes_tree.from_string("Requested resource not found") |> mist.Bytes,
      )
  }
}

type Socket(msg) {
  Socket(
    component: lustre.Runtime(msg),
    self: Subject(server_component.ClientMessage(msg)),
  )
}

type SocketMessage(msg) =
  server_component.ClientMessage(msg)

pub type SocketInit(msg) =
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
  lustre.shutdown()
  |> lustre.send(to: state.component)
}
