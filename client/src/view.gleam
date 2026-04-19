import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/server_component
import model.{
  type Model, type Msg, type Room, Empty, EnterPin, JoinLive, JoinSingle, KeyPin,
  SelectGamestyle, SelectedRoom,
}

pub fn view(model: Model) -> Element(Msg) {
  case model.state {
    Empty -> view_room_list(model.rooms)
    EnterPin(_, _) -> view_enter_pin()
    SelectGamestyle(_, _) -> view_live_or_single()
    JoinLive(room:, pin:) -> view_join_live(room, pin)
    JoinSingle(room:, pin:) -> view_join_single(room, pin)
  }
}

fn layout(header: String, ohno: option.Option(String), body: List(Element(Msg))) {
  html.div([], [
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.div([], [
          html.text(" SYSTEM READY"),
        ]),
        html.div([], [
          case ohno {
            None -> element.none()
            Some(x) -> html.h3([], [html.text("Fail: " <> x)])
          },
        ]),
        html.span([class("ml-8")], [
          html.text("<< Please Log On to use QuizTerm. >>"),
        ]),
      ]),
    ]),
    html.div([attribute.class("terminal-section")], [
      html.div([attribute.class("terminal-label mb-4")], [
        html.text(header),
      ]),
      html.div([attribute.class("participants-grid")], body),
    ]),
  ])
}

fn view_room_list(items: List(Room)) -> Element(Msg) {
  layout("Select room to play in", None, case items {
    [] -> [html.text("No rooms exist, nowhere to play! (ohno!)")]
    _ -> {
      list.index_map(items, fn(item, index) {
        room_cell(index, item, SelectedRoom)
      })
    }
  })
}

fn view_enter_pin() -> Element(Msg) {
  layout("Enter PIN code for room", None, [
    html.div([class("participant-hidden")], []),

    input_cell("[#ENTER PIN]", True, KeyPin),
    html.div([class("participant-hidden")], []),
  ])
}

fn view_join_live(room: String, pin: String) -> Element(Msg) {
  element.fragment([
    server_component.element(
      [server_component.route("/socket/game/" <> room <> "/" <> pin)],
      [],
    ),
  ])
}

fn view_join_single(room: String, pin: String) -> Element(Msg) {
  server_component.element(
    [server_component.route("/socket/game/" <> room <> "/" <> pin)],
    [],
  )
}

fn view_live_or_single() -> Element(Msg) {
  layout("Select type of play", None, [
    click_cell(1, "Live Game", model.SelectedGamestyle),
    click_cell(2, "Single Game", model.SelectedGamestyle),
  ])
}

fn input_cell(
  header: String,
  password: Bool,
  on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.div([class("participant-box")], [
    html.div([class("participant-name")], [
      html.p([], [html.text("► " <> header)]),
      html.div([], [
        html.input([
          attribute.type_(case password {
            True -> "password"
            False -> "text"
          }),
          event.on_input(on_input),
          attribute.autofocus(True),
        ]),
      ]),
    ]),
  ])
}

fn click_cell(
  number: Int,
  player: String,
  on_click: fn(String) -> msg,
) -> Element(msg) {
  html.div([class("participant-login"), event.on_click(on_click(player))], [
    html.div([class("participant-name")], [
      html.text("► " <> "[#" <> int.to_string(number) <> "] " <> player),
    ]),
  ])
}

// TODO: merge with shared.click_cell
fn room_cell(
  number: Int,
  room: Room,
  on_click: fn(String) -> msg,
) -> Element(msg) {
  html.div([class("participant-login"), event.on_click(on_click(room.id))], [
    html.div([class("participant-name")], [
      html.text("► " <> "[#" <> int.to_string(number) <> "] Team " <> room.name),
    ]),
  ])
}
