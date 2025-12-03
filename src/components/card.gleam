import gleam/dynamic/decode
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
import shared/message.{type NotifyClient, type NotifyServer, type User, User}

pub fn component() -> lustre.App(
  #(GroupRegistry(NotifyClient), Started(Subject(NotifyServer))),
  Model,
  Msg,
) {
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
    lobby: List(User),
    registry: GroupRegistry(NotifyClient),
    handler: Started(Subject(NotifyServer)),
  )
}

fn init(
  handlers: #(GroupRegistry(NotifyClient), Started(Subject(NotifyServer))),
) -> #(Model, Effect(Msg)) {
  let #(registry, handler) = handlers

  let model = Model(AskName, [], registry, handler)
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
  ReceiveName(message: String)
  AcceptName(accept: Option(String))
  GiveAnswer(name: String, answer: String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let handler = model.handler

  case msg {
    ReceiveName(name) -> #(Model(..model, state: NameOk(name)), effect.none())
    AcceptName(Some(name)) -> {
      actor.send(handler.data, message.GiveName(name:))
      #(Model(..model, state: WaitForQuiz(name)), effect.none())
    }
    AcceptName(None) -> #(Model(..model, state: AskName), effect.none())
    GiveAnswer(name, answer) -> {
      actor.send(handler.data, message.GiveAnswer(name, Some(answer)))
      #(Model(..model, state: WaitForQuiz(name)), effect.none())
    }
    SharedMessage(message.Lobby(lobby)) -> #(
      Model(..model, lobby: lobby),
      effect.none(),
    )
    SharedMessage(message.Exit) -> #(
      Model(AskName, [], model.registry, handler),
      effect.none(),
    )
    SharedMessage(message.Answer) ->
      case model.state {
        WaitForQuiz(name) -> #(
          Model(..model, state: Answer(name)),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    SharedMessage(message.Await) ->
      case model.state {
        Answer(name) -> #(
          Model(..model, state: WaitForQuiz(name)),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    SharedMessage(message.Ping) -> {
      let has_name = case model.state {
        Answer(name) -> Some(name)
        WaitForQuiz(name) -> Some(name)
        _ -> None
      }
      case has_name {
        Some(name) -> actor.send(handler.data, message.Pong(name))
        _ -> Nil
      }
      #(model, effect.none())
    }
  }
}

fn step_prompt(text: String, fetch: fn() -> Element(Msg)) {
  html.div([attribute.class("prompt-line")], [
    html.span([attribute.class("prompt-text")], [
      html.text(text),
    ]),
    fetch(),
  ])
}

fn view(model: Model) -> Element(Msg) {
  element.fragment([
    html.div([attribute.class("terminal-prompt")], [
      case model.state {
        AskName ->
          step_prompt(
            "Hello stranger. To join the quiz, I need to know your name",
            fn() { view_input("$> ", ReceiveName) },
          )
        NameOk(name) ->
          step_prompt(
            "Your name is " <> name <> "? Are you absolutely sure???",
            fn() { view_yes_no("$>", name, AcceptName) },
          )
        Answer(name) ->
          step_prompt(
            "The Quiz Lead will now ask the question, and you may answer.",
            fn() { view_named_input("Answer $>", name, GiveAnswer) },
          )
        _ -> html.h3([], [html.text("Waiting for next question")])
      },
    ]),
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.text(" SYSTEM READY"),
        html.span([class("ml-8")], [
          case model.state {
            AskName -> html.text("STATUS: Please input your name")
            NameOk(_) -> html.text("STATUS: Please validate your name")
            Answer(_) -> html.text("STATUS: Answer the question")
            _ -> html.text("STATUS: Waiting for next question")
          },
        ]),
      ]),
    ]),
    html.div([class("terminal-section")], case model.lobby {
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
      model.lobby,
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
      model.lobby,
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
      model.lobby,
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

fn view_yes_no(
  prompt: String,
  accepted: String,
  on_submit handle_keydown: fn(Option(String)) -> msg,
) -> Element(msg) {
  html.div([], [
    html.text(prompt),
    html.button([event.on_click(handle_keydown(Some(accepted)))], [
      html.text(" <Yes> "),
    ]),
    html.text(" - "),
    html.button([event.on_click(handle_keydown(None))], [html.text(" <No> ")]),
  ])
}

fn view_input(
  text: String,
  on_submit handle_keydown: fn(String) -> msg,
) -> Element(msg) {
  let on_keydown =
    event.on("keydown", {
      use key <- decode.field("key", decode.string)
      use value <- decode.subfield(["target", "value"], decode.string)

      case key {
        "Enter" if value != "" -> decode.success(handle_keydown(value))
        _ -> decode.failure(handle_keydown(""), "")
      }
    })
    |> server_component.include(["key", "target.value"])

  html.div([], [
    html.text(text),
    html.input([attribute.class("input"), on_keydown, attribute.autofocus(True)]),
  ])
}

fn view_named_input(
  text: String,
  name: String,
  on_submit handle_keydown: fn(String, String) -> msg,
) -> Element(msg) {
  let on_keydown =
    event.on("keydown", {
      use key <- decode.field("key", decode.string)
      use value <- decode.subfield(["target", "value"], decode.string)

      case key {
        "Enter" if value != "" -> decode.success(handle_keydown(name, value))
        _ -> decode.failure(handle_keydown("", ""), "")
      }
    })
    |> server_component.include(["key", "target.value"])

  html.div([], [
    html.text(text),
    html.input([attribute.class("input"), on_keydown, attribute.autofocus(True)]),
  ])
}
