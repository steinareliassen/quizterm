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
//
// Responds to:
// FetchRoom(id, <subject>) - Fetch room with the given id.

type Room {
  Room(questions: List(#(Int, String)), rooms: List(#(String, ClientsServer)))
}

pub fn initialize() {
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
            case list.length(state.rooms) > 200 {
              True -> {
                // Room not found (not really an error case), create it.
                let name = process.new_name("quiz-registry" <> id)
                let assert Ok(actor.Started(data: registry, ..)) =
                  group_registry.start(name)
                let assert Ok(actor) = statehandler.initialize(registry)
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
          Ok(_) -> state
          // Room exists, do nothing.
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
      message.SetQuestion(id:, question:) if id >= 0 && id <= 14 -> {
        Room(..state, questions: list.key_set(state.questions, id, question))
      }
      message.FetchQuestion(id:, subject:) -> {
        case
          // Find the room, if it exists
          list.key_find(state.questions, id)
        {
          Ok(question) -> actor.send(subject, Some(question))
          Error(_) -> actor.send(subject, option.None)
        }
        state
      }
      // Ignore requests for questions not between 1 and 14.
      _ -> state
    }
    |> actor.continue()
  })
  |> actor.start
}
