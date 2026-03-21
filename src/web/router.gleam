import gleam/int
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/list
import gleam/otp/actor.{type Started}
import shared/message.{type ClientsServer, type RoomControl}
import web/handlers/serve.{board, main_html, room, slow, status_head}
import wisp.{type Request, type Response}

pub fn handle_request(
  actor: Started(Subject(RoomControl(ClientsServer))),
  req: Request,
) -> Response {
  use req <- middleware(req)
  case wisp.path_segments(req) {
    ["api", ..path] -> handle_api(actor, req, path)
    _ -> handle_html(actor, req)
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
  actor: Started(Subject(RoomControl(ClientsServer))),
  req: Request,
  path: List(String),
) {
  use json <- wisp.require_json(req)

  case req.method, path {
    http.Post, ["answers"] -> decode_answers(actor, json)
    _, _ -> "nothing to see here"
  }
  |> serve.create_json_response

}

type Answers(a) {
  Answers(answers: List(a))
}

fn decode_answers(
  actor: Started(Subject(RoomControl(ClientsServer))),
  json_string: decode.Dynamic,
) {
  let decode_answer = {
    use name <- decode.field("question", decode.int)
    use email <- decode.field("answer", decode.string)
    decode.success(message.SetQuestion(name, email))
  }

  let decode_answers = {
    use answers <- decode.field("answers", decode.list(decode_answer))
    decode.success(Answers(answers:))
  }

  case decode.run(json_string, decode_answers) {
    Ok(Answers(answers)) -> {
      list.each(answers, fn(answer_question) {
        actor.send(actor.data, answer_question)
      })
      "imported "<> int.to_string(list.length(answers)) <> " items."
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
