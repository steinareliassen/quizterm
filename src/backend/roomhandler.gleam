import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import shared/message.{type RoomControl, type ClientsServer}
import backend/statehandler
import group_registry

type Room {
  Room(rooms: List(#(String, ClientsServer)))
}

pub fn initialize() {
  actor.new(Room([]))
  |> actor.on_message(fn(state: Room, message: RoomControl(ClientsServer)) {
    case message {
      message.CreateRoom(id:) -> {
        let name = process.new_name("quiz-registry" <> id)
        let assert Ok(actor.Started(data: registry, ..)) = group_registry.start(name)
        let assert Ok(actor) = statehandler.initialize(registry)
        process.send_after(actor.data, 1000, message.PingTime(actor.data))
        Room(rooms: [#(id, #(registry, actor)), ..state.rooms])
      }
      message.Response(id, a) -> {
        let assert Ok(#(_,x)) = list.find(state.rooms, fn(a) { case a {
          #(a, _) -> id == a
        }})
        actor.send(a, x)
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}

