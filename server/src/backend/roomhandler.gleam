import backend/playerhandler as player_handler
import backend/statehandler.{type StateControl}
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/list
import gleam/option.{type Option,None, Some}
import gleam/otp/actor.{type Started}
import gleam/string
import group_registry
import storail

pub type Room(actors) {
  Room(name: String, pin_enc: String, actors: actors)
}

pub type RoomInfo {
  RoomInfo(name: String, pin_enc: String)
}

pub type RoomControl(actors) {
  CreateRoom(id: String, room: RoomInfo)
  FetchRoom(id: String, pin: String, subject: Subject(Option(actors)))
  FetchRooms(subject: Subject(List(#(String, RoomInfo))))
}


type Rooms(actors) {
  Rooms(
    store: storail.Collection(#(String, RoomInfo)),
    rooms: List(#(String, Room(actors)))
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
    ])
  }
  let decode_room = {
    use id <- decode.field("id", decode.string)
    use pin_enc <- decode.field("pin_enc", decode.string)
    use name <- decode.field("name", decode.string)
    decode.success(#(id, RoomInfo(name, pin_enc)))
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
      #(id, create_room(state_handler, id, room.name, room.pin_enc))
    })
  actor.new(Rooms(store, rooms))
  |> actor.on_message(fn(state: Rooms, message: RoomControl) {
    case message {
      CreateRoom(id:, room: RoomInfo(name, pin_enc)) -> {
        let key = storail.key(state.store, id)
        case
          // Does room already exist?
          storail.read(key)
        {
          Error(_) -> {
            // Prevent overflowing server with rooms, set max 50
            case list.length(state.rooms) < 50 {
              True -> {
                // Room not found (not really an error case), create it.
                let assert Ok(_) =
                  storail.write(key, #(id, RoomInfo(name:, pin_enc:)))
                Rooms(..state, rooms: [
                  #(id, create_room(state_handler, id, name, pin_enc)),
                  ..state.rooms
                ])
              }
              False -> state
            }
          }
          // Room exists, do nothing.
          Ok(_) -> {
            echo "Attenpting to create existing room, failing"
            state
          }
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

fn create_room(
  state_handler: Started(Subject(StateControl)),
  id: String,
  name: String,
  pin_enc: String,
) -> Room {
  let assert Ok(actor.Started(data: registry, ..)) =
    group_registry.start(process.new_name("quiz-registry" <> id))
  let assert Ok(actor) = player_handler.initialize(state_handler, registry)
  process.send_after(actor.data, 1000, PingTime(actor.data))
  Room(pin_enc: pin_enc, name:, actors: #(registry, actor))
}
