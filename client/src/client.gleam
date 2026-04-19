import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/effect.{type Effect}
import model.{
  type Model, type Msg, type Room, Empty, EnterPin, Initialize, KeyPin, Model,
  Room, SelectedRoom,
}
import plinth/browser/document
import plinth/browser/element as plinth_element
import view.{view}

pub fn main() {
  let room_decoder = {
    use name <- decode.field("name", decode.string)
    use id <- decode.field("id", decode.string)
    use pin <- decode.field("key", decode.string)
    decode.success(Room(id:, name:, pin:))
  }
  let initial_items =
    document.query_selector("#model")
    |> result.map(plinth_element.inner_text)
    |> result.try(fn(json) {
      json.parse(json, decode.list(room_decoder))
      |> result.replace_error(Nil)
    })
    |> result.unwrap([])

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", #(initial_items, None))

  Nil
}

fn init(initial: #(List(Room), Option(String))) -> #(Model, Effect(Msg)) {
  let #(rooms, ohno) = initial
  let model = Model(rooms:, state: Empty, ohno:)

  #(model, effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Initialize -> init(#(model.rooms, None))
    SelectedRoom(room) -> #(
      Model(..model, state: EnterPin(room:, pin: "")),
      effect.none(),
    )
    KeyPin(pin) -> {
      case model.state {
        EnterPin(room, _) -> #(
          Model(..model, state: case string.length(pin) < 4 {
            False -> model.JoinGame(room:, pin:)
            True -> EnterPin(room:, pin:)
          }),
          effect.none(),
        )
        _ ->
          init(#(
            model.rooms,
            Some("(fail: enterpin) Invalid state, starting over"),
          ))
      }
    }
  }
}
