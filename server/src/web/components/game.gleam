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
import lustre/event
import lustre/server_component
import shared/message.{type ClientsServer, type NotifyClient, type NotifyServer}
import web/components/answerlist
import web/components/card
import web/components/shared

pub fn component() -> lustre.App(ClientsServer, Game, GameMsg) {
  lustre.application(init, update, view)
}

pub opaque type Model {
  Model(
    state: State,
    players: List(String),
    player: Option(String),
    registry: GroupRegistry(NotifyClient),
    handler: Started(Subject(NotifyServer)),
  )
}

pub type Game {
  PreGame(Model)
  SingleGame(answerlist.Model)
  LiveGame(card.Model)
}

type State {
  PickPlayer
  PickGametype
  EnterPlayer
  AskOkPlayer(name: String)
}

pub opaque type GameMsg {
  PreGameMsg(Msg)
  SingleGameMsg(answerlist.Msg)
  LiveGameMsg(card.Msg)
}

type Msg {
  PickedPlayer(Option(String))
  ReceiveName(name: String)
  AcceptPlayer(name: Option(String))
  PickedGame(String)
}

fn init(client_server: ClientsServer) -> #(Game, Effect(GameMsg)) {
  let #(registry, player_handler) = client_server
  #(
    PreGame(Model(
      PickPlayer,
      actor.call(player_handler.data, 1000, message.FetchPlayers),
      None,
      registry,
      player_handler,
    )),
    effect.none(),
  )
}

fn update(model: Game, msg: GameMsg) {
  case model, msg {
    LiveGame(model), LiveGameMsg(msg) -> {
      #(LiveGame(card.update(model, msg)), effect.none())
    }
    SingleGame(model), SingleGameMsg(msg) -> #(
      SingleGame(answerlist.update(model, msg)),
      effect.none(),
    )
    PreGame(model), PreGameMsg(msg) -> update_pregame(model, msg)
    _, _ -> #(model, effect.none())
  }
}

fn update_pregame(model: Model, msg: Msg) {
  case msg {
    PickedPlayer(player) -> #(
      PreGame(case player {
        Some(player) -> Model(..model, state: AskOkPlayer(player))
        None -> Model(..model, state: EnterPlayer)
      }),
      effect.none(),
    )
    ReceiveName(name) -> #(
      PreGame(Model(..model, state: AskOkPlayer(name))),
      effect.none(),
    )
    AcceptPlayer(Some(player)) -> {
      actor.send(model.handler.data, message.AddPlayer(player))
      #(
        PreGame(Model(..model, player: Some(player), state: PickGametype)),
        effect.none(),
      )
    }
    AcceptPlayer(None) -> #(
      PreGame(Model(..model, state: PickPlayer)),
      effect.none(),
    )
    PickedGame(game_style) ->
      case model.player {
        Some(name) ->
          case game_style {
            "Live Game" -> #(
              LiveGame(card.init(name, #(model.registry, model.handler))),
              effect.map(
                card.subscribe(model.registry, card.get_subscription_hander()),
                fn(a) { LiveGameMsg(a) },
              ),
            )
            _ -> #(
              SingleGame(answerlist.init(name, model.handler)),
              effect.none(),
            )
          }
        None -> #(PreGame(Model(..model, state: EnterPlayer)), effect.none())
      }
  }
}

fn view(model: Game) -> Element(GameMsg) {
  case model {
    LiveGame(model) ->
      element.map(card.view(model), fn(msg) { LiveGameMsg(msg) })
    SingleGame(model) ->
      element.map(answerlist.view(model), fn(msg) { SingleGameMsg(msg) })
    PreGame(model) ->
      element.map(view_pregame(model), fn(msg) { PreGameMsg(msg) })
  }
}

fn view_pregame(model: Model) -> Element(Msg) {
  element.fragment([
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.text(" SYSTEM READY"),
        html.div([class("ml-8")], [
          case model.state {
            PickPlayer -> html.text("STATUS: Please select player")
            EnterPlayer -> html.text("STATUS: Please enter your name")
            AskOkPlayer(_) -> html.text("STATUS: Validate player")
            _ -> html.text("STATUS: Waiting for next question")
          },
        ]),
      ]),
    ]),
    html.div([attribute.class("terminal-section")], [
      html.div([attribute.class("terminal-label mb-4")], [
        html.text("[ACTIVE TRANSMISSIONS]"),
      ]),
    ]),
    html.div([class("participants-grid")], [
      case model.state {
        PickPlayer ->
          case model.players {
            [] -> shared.input_new_player(ReceiveName)
            _ ->
              shared.view_players(
                list.map(model.players, fn(player) { player }),
                PickedPlayer,
              )
          }
        EnterPlayer -> shared.input_new_player(ReceiveName)
        AskOkPlayer(player) -> {
          shared.confirm_cells(
            Some("Join as this player: " <> player <> "?"),
            player,
            AcceptPlayer,
          )
        }
        PickGametype -> {
          html.div([], [
            click_cell(1, "Live Game", PickedGame),
            click_cell(2, "Single Game", PickedGame),
          ])
        }
      },
    ]),
  ])
}

fn click_cell(
  number: Int,
  text: String,
  on_click: fn(String) -> msg,
) -> Element(msg) {
  html.div([class("participant-login"), event.on_click(on_click(text))], [
    html.div([class("participant-name")], [
      html.text("► " <> "[#" <> int.to_string(number) <> "] " <> text),
    ]),
  ])
}
