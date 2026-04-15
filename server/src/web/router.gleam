import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/int
import gleam/list
import gleam/otp/actor.{type Started}
import gleam/string
import shared/message.{type RoomControl, type StateControl}
import web/handlers/serve.{html_404}
import wisp.{type Request, type Response}

pub fn handle_request(
  sha_api_key: String,
  room_handler: Started(Subject(RoomControl)),
  state_handler: Started(Subject(StateControl)),
  req: Request,
) -> Response {
  use req <- middleware(req)
  case wisp.path_segments(req) {
    [] | ["index.html"] -> serve.main_html(fetch_rooms(room_handler))
    ["api", ..path] ->
      handle_api(sha_api_key, room_handler, state_handler, req, path)

    _ -> html_404()
  }
}

fn handle_room(
  room_handler: Started(Subject(RoomControl)),
  req: Request,
  json: dynamic.Dynamic,
) {
  case req.method {
    http.Post -> add_room(room_handler, json)
    _ -> #(404, "bad api path", "Resource not found")
  }
}

fn handle_api(
  sha_api_key: String,
  room_handler: Started(Subject(RoomControl)),
  state_handler: Started(Subject(StateControl)),
  req: Request,
  path: List(String),
) {
  use json <- wisp.require_json(req)

  case list.key_find(req.headers, "x-api-key") {
    Ok(key) -> {
      case
        string.lowercase(
          bit_array.base16_encode(crypto.hash(crypto.Sha256, <<key:utf8>>)),
        )
        == string.lowercase(sha_api_key)
      {
        True ->
          case path {
            ["room"] -> handle_room(room_handler, req, json)
            [..path] -> handle_admin_api(state_handler, req, path, json)
            _ -> #(404, "bad api path", "Resource not found")
          }
        False -> {
          #(401, "invalid api key", "unauthorized")
        }
      }
    }
    Error(_) -> {
      #(401, "missing api key", "unauthorized")
    }
  }
  |> serve.create_json_response
}

fn handle_admin_api(
  actor: Started(Subject(StateControl)),
  req: Request,
  path: List(String),
  json: dynamic.Dynamic,
) {
  case req.method, path {
    http.Post, ["info"] -> decode_info(actor, json)
    http.Post, ["questions"] ->
      decode_index_to_text(actor, json, message.SetQuestion)
    http.Post, ["answers"] ->
      decode_index_to_text(actor, json, message.SetAnswer)
    _, _ -> #(404, "bad api path", "Resource not found")
  }
}

fn fetch_rooms(
  room_handler: Started(Subject(RoomControl)),
) -> List(#(String, message.RoomInfo)) {
  actor.call(room_handler.data, 1000, message.FetchRooms)
}

fn decode_info(
  actor: Started(Subject(StateControl)),
  json_string: decode.Dynamic,
) {
  let decode_uri = {
    use uri <- decode.field("teaserImage", decode.string)
    decode.success(message.SetInfo(uri))
  }
  case decode.run(json_string, decode_uri) {
    Ok(info) -> {
      actor.send(actor.data, info)
      #(200, "Updated info", "Updated info")
    }
    Error(_) -> #(400, "Unable to update info", "bad request")
  }
}

fn add_room(room_handler: Started(Subject(RoomControl)), json) {
  let decode_room = {
    use id <- decode.field("id", decode.string)
    use pin_enc <- decode.field("pin_enc", decode.string)
    use name <- decode.field("name", decode.string)
    decode.success(message.CreateRoom(
      id:,
      room: message.RoomInfo(name, pin_enc),
    ))
  }

  case decode.run(json, decode_room) {
    Ok(player) -> {
      actor.send(room_handler.data, player)
      #(200, "added room", "added room")
    }
    Error(_msg) -> #(400, "unable to add room", "bad request")
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
      #(
        200,
        "imported " <> int.to_string(list.length(answers)) <> " items.",
        "imported " <> int.to_string(list.length(answers)) <> " items.",
      )
    }
    Error(_) -> #(400, "Failed to import", "bad request")
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
