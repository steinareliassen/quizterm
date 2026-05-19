import components.{
  Answer, Box, Name, click_cell, content_cell, div_styled, terminal_header,
}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Started}
import group_registry.{type GroupRegistry}
import lustre
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import shared/message.{type ClientsServer, type NotifyClient, type NotifyServer}
import web/components/shared.{input_cell}

pub fn component() -> lustre.App(
  #(String, actor.Started(Subject(message.StateControl)), ClientsServer),
  Model,
  Msg,
) {
  lustre.application(init, update, view)
}

pub type Model {
  Model(
    state: State,
    players: List(String),
    player: Option(String),
    registry: GroupRegistry(NotifyClient),
    player_handler: Started(Subject(NotifyServer)),
    state_handler: actor.Started(Subject(message.StateControl)),
    team_id: String,
  )
}

pub type State {
  PickRoom
  EnterRoom
  AskOkRoom(name: String)
  Done(String)
}

pub type Msg {
  PickedRoom(Option(String))
  ReceiveName(name: String)
  AcceptRoom(name: Option(String))
}

fn init(
  handlers: #(
    String,
    actor.Started(Subject(message.StateControl)),
    ClientsServer,
  ),
) -> #(Model, Effect(Msg)) {
  let #(team_id, state_handler, client_server) = handlers
  let #(registry, player_handler) = client_server
  #(
    Model(
      PickRoom,
      actor.call(player_handler.data, 1000, message.FetchPlayers),
      None,
      registry,
      player_handler:,
      state_handler:,
      team_id:,
    ),
    effect.none(),
  )
}

fn update(model: Model, msg: Msg) {
  case msg {
    PickedRoom(room) -> #(
      case room {
        Some(player) -> Model(..model, state: AskOkRoom(player))
        None -> Model(..model, state: EnterRoom)
      },
      effect.none(),
    )
    ReceiveName(name) -> #(
      Model(..model, state: AskOkRoom(name)),
      effect.none(),
    )
    AcceptRoom(Some(player)) -> {
      actor.send(model.player_handler.data, message.AddPlayer(player))
      #(Model(..model, player: Some(player), state: Done("")), effect.none())
    }
    AcceptRoom(None) -> #(Model(..model, state: PickRoom), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  element.fragment([
    case model.state {
      PickRoom -> html.text("STATUS: Please select room")
      EnterRoom -> html.text("STATUS: Please enter your name")
      AskOkRoom(_) -> html.text("STATUS: Validate player")
      Done(_) -> html.text("STATUS: Leave and join again!")
    }
      |> terminal_header,
    html.div([attribute.class("terminal-section")], [
      html.div([attribute.class("terminal-label mb-4")], [
        html.text("[ACTIVE TRANSMISSIONS]"),
      ]),
    ]),
    html.div([class("participants-grid")], [
      case model.state {
        EnterRoom | PickRoom ->
          case model.state {
            PickRoom if model.players != [] ->
              view_players(
                list.map(model.players, fn(player) { player }),
                PickedRoom,
              )
            _ ->
              html.div([attribute.class("participant-box")], [
                input_cell("Enter player name:", ReceiveName),
              ])
          }
        AskOkRoom(player) -> {
          [
            content_cell("Link to this room: " <> player <> "?", None, Answer),
            click_cell(Some(player), AcceptRoom, Some("[# Yes]"), None, Name),
            click_cell(None, AcceptRoom, Some("[# No]"), None, Name),
          ]
          |> div_styled(Box)
        }
        Done(_) -> content_cell("Link to this room?", None, Answer)
      },
    ]),
  ])
}

fn view_players(players: List(String), handler: fn(Option(String)) -> msg) {
  html.div([], [
    html.div(
      [],
      list.append(
        list.index_map(players, fn(item, index) {
          Some("[ #" <> int.to_string(index) <> " ]")
          |> click_cell(Some(item), handler, _, Some(item), Name)
        }),
        [
          Some("[ # NEW ]")
          |> click_cell(None, handler, _, Some("Enter new player"), Name),
        ],
      ),
    ),
  ])
}
