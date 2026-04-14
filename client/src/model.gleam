import gleam/option.{type Option}
import rsvp.{type Error}

pub type Model {
  Model(rooms: List(Room), state: State, ohno: Option(String))
}

pub type State {
  Empty
  EnterPin(room: String, pin: String)
  SelectGamestyle(room: String, pin: String)
  JoinLive(room: String, pin: String)
  JoinSingle(room: String, pin: String)
}

pub type Msg {
  Initialize
  SelectedRoom(String)
  SelectedGamestyle(String)
  KeyPin(String)
}

pub type Room {
  Room(id: String, name: String, pin: String)
}
