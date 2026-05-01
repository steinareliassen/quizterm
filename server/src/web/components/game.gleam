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
import web/components/answerlist
import web/components/card
import web/components/shared.{input_cell}

pub fn component() -> lustre.App(
  #(String, String, actor.Started(Subject(message.StateControl)), ClientsServer),
  Game,
  GameMsg,
) {
  lustre.application(init, update, view)
}

pub opaque type Model {
  Model(
    state: State,
    players: List(String),
    player: Option(String),
    registry: GroupRegistry(NotifyClient),
    player_handler: Started(Subject(NotifyServer)),
    state_handler: actor.Started(Subject(message.StateControl)),
    team_id: String,
    team_pin: String,
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
  ListAnswers
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

fn init(
  handlers: #(
    String,
    String,
    actor.Started(Subject(message.StateControl)),
    ClientsServer,
  ),
) -> #(Game, Effect(GameMsg)) {
  let #(team_id, team_pin, state_handler, client_server) = handlers
  let #(registry, player_handler) = client_server
  #(
    PreGame(Model(
      PickPlayer,
      actor.call(player_handler.data, 1000, message.FetchPlayers),
      None,
      registry,
      player_handler:,
      state_handler:,
      team_id:,
      team_pin:,
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
      actor.send(model.player_handler.data, message.AddPlayer(player))
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
              LiveGame(card.init(
                name,
                #(model.registry, model.player_handler),
                model.team_id,
                model.team_pin,
              )),
              effect.map(
                card.subscribe(model.registry, card.get_subscription_hander()),
                fn(a) { LiveGameMsg(a) },
              ),
            )
            "Single Game" -> {
              let answer_list =
                actor.call(
                  model.state_handler.data,
                  1000,
                  message.FetchQuestions,
                )
              #(
                SingleGame(answerlist.init(
                  name,
                  answer_list,
                  model.player_handler,
                )),
                effect.none(),
              )
            }
            _ -> #(PreGame(Model(..model, state: ListAnswers)), effect.none())
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
    case model.state {
      PickPlayer -> html.text("STATUS: Please select player")
      EnterPlayer -> html.text("STATUS: Please enter your name")
      AskOkPlayer(_) -> html.text("STATUS: Validate player")
      _ -> html.text("STATUS: Waiting for next question")
    }
      |> terminal_header,
    html.div([attribute.class("terminal-section")], [
      html.div([attribute.class("terminal-label mb-4")], [
        html.text("[ACTIVE TRANSMISSIONS]"),
      ]),
    ]),
    html.div([class("participants-grid")], [
      case model.state {
        EnterPlayer | PickPlayer ->
          case model.state {
            PickPlayer if model.players != [] ->
              view_players(
                list.map(model.players, fn(player) { player }),
                PickedPlayer,
              )
            _ ->
              html.div([attribute.class("participant-box")], [
                input_cell("Enter player name:", ReceiveName),
              ])
          }
        AskOkPlayer(player) -> {
          [
            content_cell("Join as this player: " <> player, None, Answer),
            click_cell(Some(player), AcceptPlayer, Some("[# Yes]"), None, Name),
            click_cell(None, AcceptPlayer, Some("[# No]"), None, Name),
          ]
          |> div_styled(Box)
        }
        PickGametype -> {
          html.div([], [
            click(1, "Live Game"),
            click(2, "Single Game"),
            click(3, "View (non-live game) answers from players in room"),
          ])
        }
        ListAnswers -> list_answers(model.player_handler)
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

fn list_answers(player_handler: Started(Subject(NotifyServer))) {
  html.div(
    [],
    list.map(
      actor.call(player_handler.data, 2000, message.FetchAllAnswers),
      fn(line) {
        let #(num, num_list) = line
        html.div([], [
          html.text(int.to_string(num)),
          ..list.map(num_list, fn(num_line) {
            let #(player, answer) = num_line
            html.div([], [html.text(player <> " : " <> answer)])
          })
        ])
      },
    ),
  )
}

fn click(number: Int, text: String) -> Element(Msg) {
  Some("► " <> "[#" <> int.to_string(number) <> "] " <> text)
  |> click_cell(text, PickedGame, _, None, Box)
}
