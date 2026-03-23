import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/int
import gleam/list
import gleam/otp/actor.{type Started}
import shared/message.{type ClientsServer, type RoomControl, type StateControl}
import web/handlers/serve.{board, main_html, room, slow, status_head}
import wisp.{type Request, type Response}

pub fn handle_request(
  room_handler: Started(Subject(RoomControl(ClientsServer))),
  state_handler: Started(Subject(StateControl)),
  req: Request,
) -> Response {
  use req <- middleware(req)
  case wisp.path_segments(req) {
    ["api", ..path] -> handle_api(state_handler, req, path)
    _ -> handle_html(room_handler, req)
  }
}

fn handle_html(
  actor: Started(Subject(RoomControl(ClientsServer))),
  req: Request,
) -> Response {
  case wisp.path_segments(req) {
    ["slow", id] -> slow(actor, id)
    ["board", id] -> board(actor, id)
    ["room", id] -> room(actor, id)
    _ -> status_head("Nothing to see here")
  }
  |> main_html
}

fn handle_api(
  actor: Started(Subject(StateControl)),
  req: Request,
  path: List(String),
) {
  use json <- wisp.require_json(req)

  case list.key_find(req.headers, "x-api-key") {
    Ok(key) -> {
      case
        bit_array.base64_encode(crypto.hash(crypto.Sha256, <<key:utf8>>), True)
        == "1nIr1fQzs0K9UZAeUcG/67n12iRiviIS6gO5WXyI2+0="
      {
        True ->
          case req.method, path {
            http.Post, ["info"] -> decode_info(actor, json)
            http.Post, ["questions"] ->
              decode_index_to_text(actor, json, message.SetQuestion)
            http.Post, ["answers"] ->
              decode_index_to_text(actor, json, message.SetAnswer)
            _, _ -> "nothing to see here"
          }
        False -> "invalid api key"
      }
    }
    Error(_) -> "missing api key"
  }
  |> serve.create_json_response
}

fn decode_info(
  actor: Started(Subject(StateControl)),
  json_string: decode.Dynamic,
) {
  let decode_uri = {
    use uri <- decode.field("uri", decode.string)
    decode.success(message.SetInfo(uri))
  }
  case decode.run(json_string, decode_uri) {
    Ok(info) -> {
      actor.send(actor.data, info)
      "Updated info"
    }
    Error(_) -> "error parsing json, failed to update info."
  }
}

fn decode_index_to_text(
  actor: Started(Subject(StateControl)),
  json_string: decode.Dynamic,
  message: fn(Int, String) -> StateControl,
) {
  let decode_answer = {
    use index <- decode.field("index", decode.int)
    use text <- decode.field("text", decode.string)
    decode.success(message(index, text))
  }

  case decode.run(json_string, decode.list(decode_answer)) {
    Ok(answers) -> {
      list.each(answers, fn(answer_question) {
        actor.send(actor.data, answer_question)
      })
      "imported " <> int.to_string(list.length(answers)) <> " items."
    }
    Error(_) -> "error parsing json, failed to import answers."
  }
}

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)
  handle_request(req)
}
