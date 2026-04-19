import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor.{type Started}
import group_registry.{type GroupRegistry}
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/server_component
import shared/message.{type NotifyClient, type NotifyServer, type User, User}
import web/components/shared.{step_prompt, view_input}

type State {
  Wait
  Answer
}

pub opaque type Model {
  Model(
    state: State,
    name: String,
    lobby: #(String, List(User)),
    registry: GroupRegistry(NotifyClient),
    handler: Started(Subject(NotifyServer)),
  )
}

pub fn init(name: String, handlers: message.ClientsServer) -> Model {
  let #(registry, handler) = handlers
  actor.send(handler.data, message.GiveName(name:))
  Model(Wait, name, #("", []), registry, handler)
}

pub fn get_subscription_hander() {
  SharedMessage
}

pub fn subscribe(
  registry: GroupRegistry(NotifyClient),
  on_msg handle_msg: fn(NotifyClient) -> msg,
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
  GiveAnswer(answer: String)
}

pub fn update(model: Model, msg: Msg) -> Model {
  let handler = model.handler

  case msg {
    GiveAnswer(answer) -> {
      actor.send(handler.data, message.GiveAnswer(model.name, Some(answer)))
      Model(..model, state: Wait)
    }
    SharedMessage(shared_msg) -> handle_server_message(model, shared_msg)
  }
}

fn handle_server_message(model: Model, notify_client) {
  case notify_client {
    message.Lobby(question, lobby) -> Model(..model, lobby: #(question, lobby))
    message.Answer -> Model(..model, state: Answer)
    message.Await -> Model(..model, state: Wait)
    message.Ping -> {
      actor.send(model.handler.data, message.Pong(model.name))
      model
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let #(question, lobby) = model.lobby
  element.fragment([
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.text(" SYSTEM READY"),
        html.span([class("ml-8")], [
          case model.state {
            Answer ->
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
      Answer -> {
        html.div([attribute.class("terminal-prompt")], [
          step_prompt(
            "The Quiz Lead will now ask the question, and you may answer.",
            fn() { view_input(GiveAnswer) },
          ),
        ])
      }
      _ -> {
        html.div([attribute.class("terminal-prompt")], [
          html.h3([], [html.text("Waiting for next question")]),
        ])
      }
    },
    element.fragment([
      html.div([class("terminal-section")], case lobby {
        [] -> []
        lobby -> {
          let answered =
            list.filter(lobby, fn(x) {
              case x.answer {
                message.IDontKnow | message.HasAnswered | message.GivenAnswer(_) ->
                  True
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
      // TODO:
      // "/socket/control/" <> model.team_id <> "/" <> model.team_pin,
      server_component.element(
        [server_component.route("/socket/control/TMA/PINA")],
        [],
      ),
    ]),
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
