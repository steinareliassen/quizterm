import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Started}
import gleam/string
import group_registry.{type GroupRegistry}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
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
  }
}

fn view(model: Model) -> Element(Msg) {
  element.fragment([
    keyed.div([attribute.class("center")], [
      #("header", html.h1([], [html.text("QUIZTerminal")])),
      case model.state {
        AskName -> #(
          "name",
          html.div([], [
            html.h3([], [
              html.text(
                "Hello stranger. To join the quiz, I need to know your name",
              ),
            ]),
            view_input("Name $> ", ReceiveName),
          ]),
        )
        NameOk(name) -> #(
          "accept",
          html.div([], [
            html.h3([], [
              html.text(
                "Your name is " <> name <> "? Are you absolutely sure???",
              ),
            ]),
            view_accept("Press <Y>es or <N>o $>", name, AcceptName),
          ]),
        )
        Answer(name) -> #(
          "answer",
          html.div([], [
            html.h3([], [
              html.text(
                "The Quiz Lead will now ask the question, and you may answer.",
              ),
            ]),
            view_named_input("Answer $>", name, GiveAnswer),
          ]),
        )
        _ -> #("await", html.h3([], [html.text("Waiting for next question")]))
      },
    ]),
    html.div([attribute.class("under")], case model.lobby {
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
          html.div([attribute.class("under_cell_nb")], []),
          html.div([attribute.class("under_cell")], [
            html.h3([], [
              html.text("Answered:"),
            ]),
            case answered == size {
              True -> html.text("Everyone!")
              False -> html.text(answered <> "/" <> size)
            },
          ]),
          html.div([attribute.class("under_cell_nb")], []),
        ]
      }
    }),
    html.div(
      [attribute.class("under")],
      list.filter(model.lobby, fn(x) {
        case x.answer {
          message.GivenAnswer(_) | message.HasAnswered -> True
          _ -> False
        }
      })
        |> list.map(fn(user) {
          let User(name, answer) = user
          case answer {
            message.GivenAnswer(answer) -> answer
            message.HasAnswered -> "Answer Given"
            _ -> "Odd State..."
          }
          |> content_cell(name, _)
        }),
    ),
    html.div(
      [attribute.class("under")],
      list.filter(model.lobby, fn(x) {
        case x.answer {
          message.IDontKnow -> True
          _ -> False
        }
      })
        |> list.map(fn(user) {
          let User(name, _) = user
          content_cell(name, "P.A.S.S :(")
        }),
    ),
    html.div(
      [attribute.class("under")],
      list.filter(model.lobby, fn(x) {
        case x.answer {
          message.NotAnswered -> True
          _ -> False
        }
      })
        |> list.map(fn(user) {
          case user {
            User(name, _) -> content_cell(name, "Not Answered")
          }
        }),
    ),
  ])
}

fn content_cell(header: String, content: String) {
  html.div([attribute.class("under_cell")], [
    html.h3([], [
      html.text(header),
    ]),
    html.text(content),
  ])
}

fn view_accept(
  prompt: String,
  accepted: String,
  on_submit handle_keydown: fn(Option(String)) -> msg,
) -> Element(msg) {
  let on_keydown =
    event.on("keydown", {
      use value <- decode.field("key", decode.string)
      let result = case string.lowercase(value) {
        "y" -> Some(accepted)
        _ -> None
      }
      decode.success(handle_keydown(result))
    })
    |> server_component.include(["key"])

  html.div([], [
    html.text(prompt),
    html.input([
      attribute.class("input"),
      on_keydown,
      attribute.autofocus(True),
    ]),
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
