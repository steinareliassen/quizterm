import backend/playerhandler as player_handler
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor.{type Started}
import group_registry
import shared/message.{type ClientsServer, type RoomControl, type StateControl}

// Room handler, actor to hold the rooms for the different teams playing.
//
// Reacts to:
// CreateRoom(id) - create room with given ID.
//
// Responds to:
// FetchRoom(id, <subject>) - Fetch room with the given id.

type Room {
  Room(questions: List(#(Int, String)), rooms: List(#(String, ClientsServer)))
}

pub fn initialize(state_handler: Started(Subject(StateControl))) {
  actor.new(Room([], []))
  |> actor.on_message(fn(state: Room, message: RoomControl(ClientsServer)) {
    case message {
      message.CreateRoom(id:) -> {
        case
          // Does room already exist?
          state.rooms |> list.key_find(id)
        {
          Error(_) -> {
            // Prevent overflowing server with rooms, set max 200
            case list.length(state.rooms) < 200 {
              True -> {
                // Room not found (not really an error case), create it.
                let name = process.new_name("quiz-registry" <> id)
                let assert Ok(actor.Started(data: registry, ..)) =
                  group_registry.start(name)
                let assert Ok(actor) = player_handler.initialize(state_handler, registry)
                process.send_after(
                  actor.data,
                  1000,
                  message.PingTime(actor.data),
                )
                Room(..state, rooms: [#(id, #(registry, actor)), ..state.rooms])
              }
              False -> state
            }
          }
          // Room exists, do nothing.
          Ok(_) -> state
        }
      }
      message.FetchRoom(id:, subject:) -> {
        case
          // Find the room, if it exists
          state.rooms |> list.key_find(id)
        {
          Ok(room) -> actor.send(subject, Some(room))
          Error(_) -> actor.send(subject, option.None)
        }
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}
