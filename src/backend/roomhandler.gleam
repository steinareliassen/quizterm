import backend/statehandler
import gleam/erlang/process
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import group_registry
import shared/message.{type ClientsServer, type RoomControl}

// Room handler, actor to hold the rooms for the different teams playing.
//
// Reacts to:
// CreateRoom(id) - create room with given ID.
// Todo: better handling of "room already exists"
//
// Responds to:
// FetchRoom(id, <subject>) - Fetch room with the given id.
//
type Room {
  Room(rooms: List(#(String, ClientsServer)))
}

pub fn initialize() {
  actor.new(Room([]))
  |> actor.on_message(fn(state: Room, message: RoomControl(ClientsServer)) {
    case message {
      message.CreateRoom(id:) -> {
        case // Does room already exist?
          list.find(state.rooms, fn(a) {
            case a {
              #(a, _) -> id == a
            }
          })
        {
          Error(_) -> {
            // Room not found (not really an error case), create it.
            let name = process.new_name("quiz-registry" <> id)
            let assert Ok(actor.Started(data: registry, ..)) =
              group_registry.start(name)
            let assert Ok(actor) = statehandler.initialize(registry)
            process.send_after(actor.data, 1000, message.PingTime(actor.data))
            Room(rooms: [#(id, #(registry, actor)), ..state.rooms])
          }
          Ok(_) -> state // Room already exist, do nothing (for now...)
        }
      }
      message.FetchRoom(id:, subject:) -> {
        case // Find the room, if it exists
          list.find(state.rooms, fn(a) {
            case a {
              #(a, _) -> id == a
            }
          })
        {
          Ok(#(_, room)) -> actor.send(subject, Some(room))
          Error(_) -> actor.send(subject, option.None)
        }
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}
