import gleam/option.{type Option}

pub type Model {
  Model(rooms: List(Room), state: State, ohno: Option(String))
}

pub type State {
  Empty
  EnterPin(room: String, pin: String)
  JoinGame(room: String, pin: String)
}

pub type Msg {
  Initialize
  SelectedRoom(String)
  KeyPin(String)
}

pub type Room {
  Room(id: String, name: String, pin: String)
}
