import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
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
  let registry = model.registry
  let handler = model.handler
  let lobby = model.lobby

  case msg {
    ReceiveName(name) -> {
      #(Model(NameOk(name), lobby, registry, handler), effect.none())
    }
    AcceptName(name) -> {
      case name {
        Some(name) -> {
          actor.send(handler.data, message.GiveName(name:))
          #(Model(WaitForQuiz(name), lobby, registry, handler), effect.none())
        }
        _ -> #(Model(AskName, lobby, registry, handler), effect.none())
      }
    }
    GiveAnswer(name, answer) -> {
      actor.send(handler.data, message.GiveAnswer(name, answer))
      #(Model(WaitForQuiz(name), lobby, registry, handler), effect.none())
    }

    SharedMessage(message:) -> {
      let state = case model.state {
        WaitForQuiz(name) ->
          case message {
            message.Answer -> Answer(name)
            _ -> model.state
          }
        _ -> model.state
      }

      case message {
        message.Lobby(lobby) -> #(
          Model(state, lobby, registry, handler),
          effect.none(),
        )
        message.Answer ->
          case model.state {
            WaitForQuiz(name) -> #(
              Model(Answer(name), lobby, registry, handler),
              effect.none(),
            )
            _ -> #(Model(state, lobby, registry, handler), effect.none())
          }
        message.Await ->
          case model.state {
            Answer(name) -> #(
              Model(WaitForQuiz(name), lobby, registry, handler),
              effect.none(),
            )
            _ -> #(Model(state, lobby, registry, handler), effect.none())
          }
      }
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
          view_input("Enter your name to join the quiz: ", ReceiveName),
        )
        NameOk(name) -> {
          #(
            "accept",
            view_accept(
              "Are you ok with the name " <> name <> "? (y/n)",
              name,
              AcceptName,
            ),
          )
        }
        Answer(name) -> {
          #(
            "answer",
            view_named_input("Answer the question: ", name, GiveAnswer),
          )
        }
        _ -> {
          #("history", view_ask_question("Waiting for next question"))
        }
      },
    ]),
    html.div(
      [attribute.class("under")],
      list.map(model.lobby, fn(user) {
        let User(name, answer) = user
        let answer = case answer {
          None -> "waiting..."
          Some(answer) -> answer
        }
        html.div([attribute.class("under_cell")], [
          html.h3([], [
            html.text(name),
          ]),
          html.text(answer),
        ])
      }),
    ),
  ])
}

fn view_ask_question(question: String) -> Element(msg) {
  html.text(question)
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
