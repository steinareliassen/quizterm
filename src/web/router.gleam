import gleam/erlang/process.{type Subject}
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
    ["board", id, "slow"] -> slow(actor, id)
    ["board", id] -> board(actor, id)
    ["room", id] -> room(actor, id)
    _ -> status_head("Nothing to see here")
  }
  |> main_html
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
