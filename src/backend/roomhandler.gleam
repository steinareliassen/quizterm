import backend/statehandler
import gleam/erlang/process
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import group_registry
import shared/message.{type ClientsServer, type RoomControl}

type Room {
  Room(rooms: List(#(String, ClientsServer)))
}

pub fn initialize() {
  actor.new(Room([]))
  |> actor.on_message(fn(state: Room, message: RoomControl(ClientsServer)) {
    case message {
      message.CreateRoom(id:) -> {
        let name = process.new_name("quiz-registry" <> id)
        let assert Ok(actor.Started(data: registry, ..)) =
          group_registry.start(name)
        let assert Ok(actor) = statehandler.initialize(registry)
        process.send_after(actor.data, 1000, message.PingTime(actor.data))
        Room(rooms: [#(id, #(registry, actor)), ..state.rooms])
      }
      message.Response(id, a) -> {
        case
          list.find(state.rooms, fn(a) {
            case a {
              #(a, _) -> id == a
            }
          })
        {
          Ok(#(_, room)) -> actor.send(a, Some(room))
          Error(_) -> actor.send(a, option.None)
        }
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}
