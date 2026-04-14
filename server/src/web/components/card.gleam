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
import lustre/server_component
import shared/message.{type NotifyClient, type NotifyServer, type User, User}
import web/components/shared.{
  input_new_player, step_prompt, view_named_input, view_players,
}

pub fn component() -> lustre.App(message.ClientsServer, Model, Msg) {
  lustre.application(init, update, view)
}

type State {
  AskName
  NameOk(String)
  WaitForQuiz(String)
  Answer(String)
}

pub opaque type Model {
  Model(
    state: State,
    players: List(#(String, #(String, List(#(String, String))))),
    lobby: #(String, List(User)),
    registry: GroupRegistry(NotifyClient),
    handler: Started(Subject(NotifyServer)),
  )
}

fn init(handlers: message.ClientsServer) -> #(Model, Effect(Msg)) {
  let #(registry, handler) = handlers

  let model =
    Model(
      AskName,
      actor.call(handler.data, 1000, message.FetchPlayers),
      #("", []),
      registry,
      handler,
    )
  #(model, subscribe(registry, SharedMessage))
}

fn subscribe(
  registry: GroupRegistry(topic),
  on_msg handle_msg: fn(topic) -> msg,
) -> Effect(msg) {
  use _, _ <- server_component.select
  let subject = group_registry.join(registry, "quiz", process.self())

  let selector =
    process.new_selector()
    |> process.select_map(subject, handle_msg)

  selector
}

pub opaque type Msg {
  SharedMessage(message: NotifyClient)
  ReceiveName(Option(String))
  AcceptName(Option(#(String, String)))
  GiveAnswer(name: String, answer: String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let handler = model.handler

  case msg {
    ReceiveName(Some(name)) -> #(
      Model(..model, state: NameOk(name)),
      effect.none(),
    )
    AcceptName(Some(name)) -> {
      let #(_, name) = name
      actor.send(handler.data, message.GiveName(name))
      #(Model(..model, state: WaitForQuiz(name)), effect.none())
    }
    AcceptName(None) -> #(Model(..model, state: AskName), effect.none())
    GiveAnswer(name, answer) -> {
      actor.send(handler.data, message.GiveAnswer(name, Some(answer)))
      #(Model(..model, state: WaitForQuiz(name)), effect.none())
    }
    SharedMessage(shared_msg) -> #(
      handle_server_message(model, shared_msg),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_server_message(model: Model, notify_client) {
  case notify_client {
    message.Lobby(question, lobby) -> Model(..model, lobby: #(question, lobby))
    message.Exit ->
      Model(AskName, model.players, #("", []), model.registry, model.handler)
    message.Answer ->
      case model.state {
        // We are currently waiting for next quiz question, ok to switch to answer mode
        WaitForQuiz(name) -> Model(..model, state: Answer(name))
        // We are not in a state to react, ignore switch to answer mode.
        _ -> model
      }
    message.Await ->
      case model.state {
        Answer(name) -> Model(..model, state: WaitForQuiz(name))
        _ -> model
      }
    message.Ping -> {
      let has_name = case model.state {
        Answer(name) -> Some(name)
        WaitForQuiz(name) -> Some(name)
        _ -> None
      }
      case has_name {
        Some(name) -> actor.send(model.handler.data, message.Pong(name))
        _ -> Nil
      }
      model
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  let #(question, lobby) = model.lobby
  element.fragment([
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.text(" SYSTEM READY"),
        html.span([class("ml-8")], [
          case model.state {
            AskName -> html.text("STATUS: Please input your name")
            NameOk(_) -> html.text("STATUS: Please validate your name")
            Answer(_) ->
              html.div([], [
                html.div([], [html.text("STATUS: Answer the following:")]),
                html.div([], [html.text(question)]),
              ])
            _ -> html.text("STATUS: Waiting for next question")
          },
        ]),
      ]),
    ]),

    case model.state {
      AskName -> {
        html.div([class("participants-grid")], [
          case model.players {
            [] -> input_new_player(ReceiveName)
            _ ->
              view_players(
                list.map(model.players, fn(player) {
                  let #(id, #(name, _)) = player
                  #(id, name)
                }),
                AcceptName,
              )
          },
        ])
      }
      NameOk(name) -> {
        html.div([class("participants-grid")], [
          shared.confirm_cells(
            Some("Join as this player: " <> name <> "?"),
            #("", name),
            AcceptName,
          ),
        ])
      }
      Answer(name) -> {
        html.div([attribute.class("terminal-prompt")], [
          step_prompt(
            "The Quiz Lead will now ask the question, and you may answer.",
            fn() { view_named_input(name, GiveAnswer) },
          ),
        ])
      }
      _ -> {
        html.div([attribute.class("terminal-prompt")], [
          html.h3([], [html.text("Waiting for next question")]),
        ])
      }
    },
    case model.state {
      Answer(_) | WaitForQuiz(_) ->
        element.fragment([
          html.div([class("terminal-section")], case lobby {
            [] -> []
            lobby -> {
              let answered =
                list.filter(lobby, fn(x) {
                  case x.answer {
                    message.IDontKnow
                    | message.HasAnswered
                    | message.GivenAnswer(_) -> True
                    _ -> False
                  }
                })
                |> list.length
                |> int.to_string
              let size = lobby |> list.length |> int.to_string
              [
                html.div([attribute.class("terminal-box")], [
                  html.span([attribute.class("terminal-label")], [
                    html.text("[PROGRESS] "),
                  ]),
                  html.text("Answered: "),
                  case answered == size {
                    True -> html.text("Everyone!")
                    False -> html.text(answered <> "/" <> size)
                  },
                ]),
              ]
            }
          }),
          terminal_section(
            lobby,
            "[ACTIVE TRANSMISSIONS]",
            fn(x) {
              case x.answer {
                message.GivenAnswer(_) | message.HasAnswered -> True
                _ -> False
              }
            },
            fn(user) {
              let User(name, ping_time, answer) = user
              case answer {
                message.GivenAnswer(answer) -> answer
                message.HasAnswered -> "Answer Given"
                _ -> "Odd State..."
              }
              |> content_cell(name, ping_time, _)
            },
          ),
          terminal_section(
            lobby,
            "[P A S S]",
            fn(x) {
              case x.answer {
                message.IDontKnow -> True
                _ -> False
              }
            },
            fn(user) {
              let User(name, ping_time, _) = user
              content_cell(name, ping_time, "P.A.S.S :(")
            },
          ),
          terminal_section(
            lobby,
            "[AWAITING RESPONSE]",
            fn(x) {
              case x.answer {
                message.NotAnswered -> True
                _ -> False
              }
            },
            fn(user) {
              case user {
                User(name, ping_time, _) ->
                  content_cell(name, ping_time, "Not Answered")
              }
            },
          ),
          server_component.element(
            [server_component.route("/socket/control/TMA/PINA")],
            [],
          ),
        ])
      _ -> element.none()
    },
  ])
}

fn terminal_section(
  lobby: List(User),
  header: String,
  filter: fn(User) -> Bool,
  extract: fn(User) -> Element(Msg),
) {
  html.div([attribute.class("terminal-section")], [
    html.div([attribute.class("terminal-label mb-4")], [
      html.text(header),
    ]),
    html.div(
      [attribute.class("participants-grid")],
      list.filter(lobby, filter)
        |> list.map(extract),
    ),
  ])
}

fn content_cell(header: String, ping_time: Int, content: String) -> Element(Msg) {
  html.div(
    [
      class(case ping_time > 1 {
        True -> "participant-disconnect"
        False -> "participant-box"
      }),
    ],
    [
      html.div([class("participant-name")], [
        html.text("► " <> header),
      ]),
      html.div([class("participant-answer")], [
        html.text(content),
      ]),
    ],
  )
}
