import backend/playerhandler as player_handler
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Started}
import gleam/string
import group_registry
import shared/message.{
  type Room, type RoomControl, type RoomInfo, type StateControl, CreateRoom,
  FetchRoom, FetchRoomChecked, FetchRooms, PingTime, Room, RoomInfo,
}
import storail

// Room handler, actor to hold the rooms for the different teams playing.
//
// Reacts to:
// CreateRoom(id, name, pin_enc) - create room with given ID, name and encoded pin
//
// Responds to:
// FetchRoom(id, <subject>) - Fetch room with the given id.
// FetchRooms(<subject>) - Fetch list of rooms.

type Rooms {
  Rooms(
    store: storail.Collection(#(String, RoomInfo)),
    rooms: List(#(String, Room)),
  )
}

pub fn initialize(state_handler: Started(Subject(StateControl))) {
  let config = storail.Config(storage_path: "/tmp/data/storage")

  let encode_room = fn(id_room: #(String, RoomInfo)) {
    let #(id, room) = id_room
    json.object([
      #("id", json.string(id)),
      #("name", json.string(room.name)),
      #("pin_enc", json.string(room.pin_enc)),
      #("room_key", json.nullable(room.room_key, fn(key) { json.string(key) })),
    ])
  }
  let decode_room = {
    use id <- decode.field("id", decode.string)
    use pin_enc <- decode.field("pin_enc", decode.string)
    use name <- decode.field("name", decode.string)
    use room_key <- decode.field("room_key", decode.optional(decode.string))
    decode.success(#(id, RoomInfo(name, pin_enc, room_key:)))
  }

  // Define a collection for a data type in your application.
  let store =
    storail.Collection(
      name: "rooms",
      to_json: encode_room,
      decoder: decode_room,
      config:,
    )

  let room_infos = case storail.list(store, []) {
    Error(_) -> {
      echo "Something wrong!"
      []
    }
    Ok(roomlist) -> {
      list.filter_map(roomlist, fn(id: String) {
        let key = storail.key(store, id)
        storail.read(key)
      })
    }
  }

  let rooms =
    list.map(room_infos, fn(info) {
      let #(id, room) = info
      #(
        id,
        create_room(state_handler, id, room.name, room.pin_enc, room.room_key),
      )
    })
  actor.new(Rooms(store, rooms))
  |> actor.on_message(fn(state: Rooms, message: RoomControl) {
    case message {
      CreateRoom(id:, room: RoomInfo(name, pin_enc, room_key)) -> {
        let key = storail.key(state.store, id)
        case
          // Does room already exist?
          storail.read(key)
        {
          Error(_) ->
            // Prevent overflowing server with rooms, set max 50
            case list.length(state.rooms) < 50 {
              True -> {
                // Room not found (not an error...), create it.
                let assert Ok(_) =
                  storail.write(key, #(id, RoomInfo(name:, pin_enc:, room_key:)))
                Rooms(..state, rooms: [
                  #(id, create_room(state_handler, id, name, pin_enc, room_key)),
                  ..state.rooms
                ])
              }
              False -> state
            }

          // Room exists, do nothing.
          Ok(_) -> {
            echo "Attenpting to create existing room, failing"
            state
          }
        }
      }
      FetchRoom(id:, subject:) -> {
        let message = case
          // Find the room, if it exists
          state.rooms |> list.key_find(id)
        {
          Ok(Room(_, _, _, actors)) -> Some(actors)
          _ -> None
        }
        actor.send(subject, message)
        state
      }
      FetchRoomChecked(id:, pin_or_key:, is_pin:, subject:) -> {
        let message = case
          // Find the room, if it exists
          state.rooms |> list.key_find(id)
        {
          Ok(Room(_, pin_enc, room_key, actors)) -> {
            let pin_enc = string.uppercase(pin_enc)
            let crypt_key =
              bit_array.base16_encode(
                crypto.hash(crypto.Sha256, <<pin_or_key:utf8>>),
              )
            case is_pin {
              True if pin_enc == crypt_key -> Some(actors)
              False if room_key == Some(pin_or_key) -> Some(actors)
              _ -> None
            }
          }
          _ -> None
        }
        actor.send(subject, message)
        state
      }
      FetchRooms(subject:) -> {
        // Transform from Room to RoomInfo and ship back
        state.rooms
        |> list.map(fn(id_room) {
          let #(id, Room(name, pin_enc, room_key, _)) = id_room
          #(id, message.RoomInfo(name:, pin_enc:, room_key:))
        })
        |> actor.send(subject, _)
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}

fn create_room(
  state_handler: Started(Subject(StateControl)),
  id: String,
  name: String,
  pin_enc: String,
  room_key: Option(String),
) -> Room {
  let assert Ok(actor.Started(data: registry, ..)) =
    group_registry.start(process.new_name("quiz-registry" <> id))
  let assert Ok(actor) = player_handler.initialize(state_handler, registry)
  process.send_after(actor.data, 1000, PingTime(actor.data))
  Room(pin_enc:, name:, room_key:, actors: #(registry, actor))
}
