import backend/playerhandler as player_handler
import gleam/bit_array
import gleam/crypto
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor.{type Started}
import gleam/string
import group_registry
import shared/message.{
  type Room, type RoomControl, type StateControl, CreateRoom, FetchRoom,
  FetchRooms, PingTime, Room, RoomInfo,
}

// Room handler, actor to hold the rooms for the different teams playing.
//
// Reacts to:
// CreateRoom(id, name, pin_enc) - create room with given ID, name and encoded pin
//
// Responds to:
// FetchRoom(id, <subject>) - Fetch room with the given id.
// FetchRooms(<subject>) - Fetch list of rooms.

type Rooms {
  Rooms(rooms: List(#(String, Room)))
}

pub fn initialize(state_handler: Started(Subject(StateControl))) {
  actor.new(Rooms([]))
  |> actor.on_message(fn(state: Rooms, message: RoomControl) {
    case message {
      CreateRoom(id:, room: RoomInfo(name, pin_enc)) -> {
        case
          // Does room already exist?
          state.rooms |> list.key_find(id)
        {
          Error(_) -> {
            // Prevent overflowing server with rooms, set max 50
            case list.length(state.rooms) < 50 {
              True -> {
                // Room not found (not really an error case), create it.
                let assert Ok(actor.Started(data: registry, ..)) =
                  group_registry.start(process.new_name("quiz-registry" <> id))
                let assert Ok(actor) =
                  player_handler.initialize(state_handler, registry)
                process.send_after(actor.data, 1000, PingTime(actor.data))
                Rooms(rooms: [
                  #(
                    id,
                    Room(pin_enc: pin_enc, name:, actors: #(registry, actor)),
                  ),
                  ..state.rooms
                ])
              }
              False -> state
            }
          }
          // Room exists, do nothing.
          Ok(_) -> state
        }
      }
      FetchRoom(id:, pin:, subject:) -> {
        case
          // Find the room, if it exists
          state.rooms |> list.key_find(id)
        {
          Ok(Room(_, pin_enc, actors)) -> {
            case
              string.uppercase(pin_enc)
              == bit_array.base16_encode(
                crypto.hash(crypto.Sha256, <<pin:utf8>>),
              )
            {
              True -> actor.send(subject, Some(actors))
              False -> actor.send(subject, None)
            }
          }
          _ -> actor.send(subject, option.None)
        }
        state
      }
      FetchRooms(subject:) -> {
        // Transform from Room to RoomInfo and ship back
        state.rooms
        |> list.map(fn(id_room) {
          let #(id, Room(name, pin_enc, _)) = id_room
          #(id, message.RoomInfo(name:, pin_enc:))
        })
        |> actor.send(subject, _)
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}
