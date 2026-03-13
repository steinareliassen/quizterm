import components/components.{step_prompt}
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
import shared/message.{type NotifyClient, type NotifyServer}

pub fn component() -> lustre.App(
  #(GroupRegistry(NotifyClient), Started(Subject(NotifyServer))),
  Model,
  Msg,
) {
  lustre.application(init, update, view)
}

pub opaque type Model {
  Model(
    state: Msg,
    answers: List(#(Int, String)),
    handler: Started(Subject(NotifyServer)),
  )
}

fn init(
  handlers: #(GroupRegistry(NotifyClient), Started(Subject(NotifyServer))),
) -> #(Model, Effect(Msg)) {
  let #(_, handler) = handlers
  update(Model(Initial, [], handler), Initial)
}

pub opaque type Msg {
  Initial
  SharedMessage(message: NotifyClient)
  ReceiveName(message: String)
  AcceptName(accept: Option(String))
  GiveQuestion(name: String, question: String)
  GiveAnswer(name: String, question: Int, answer: String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Initial | SharedMessage(_) -> #(model, effect.none())
    AcceptName(None) -> #(Model(Initial, [], model.handler), effect.none())
    AcceptName(Some(name)) -> {
      #(Model(..model, state: GiveQuestion(name, "")), effect.none())
    }
    GiveQuestion(name, question) ->
      case int.parse(question) {
        Ok(question) if question >= 1 && question <= 14 -> #(
          Model(..model, state: GiveAnswer(name:, question:, answer: "")),
          effect.none(),
        )
        _ -> #(
          Model(..model, state: GiveQuestion(name:, question: "")),
          effect.none(),
        )
      }
    GiveAnswer(name, question, answer) -> {
      #(
        Model(
          ..model,
          state: GiveQuestion(name, ""),
          answers: list.key_set(model.answers, question, answer),
        ),
        effect.none(),
      )
    }
    ReceiveName(_) -> #(Model(..model, state: msg), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  element.fragment([
    html.div([attribute.class("terminal-prompt")], [
      case model.state {
        Initial ->
          step_prompt(
            "Hello stranger. To join the quiz, I need to know your name",
            fn() { components.view_input(ReceiveName) },
          )
        ReceiveName(name) ->
          step_prompt(
            "Your name is " <> name <> "? Are you absolutely sure???",
            fn() { components.view_yes_no(name, AcceptName) },
          )
        GiveQuestion(name, _) ->
          step_prompt(
            "Enter the number of the question you want to answer",
            fn() {
              components.view_named_input(name, GiveQuestion)
            },
          )
        GiveAnswer(name, question, _) ->
          step_prompt(
            "Enter the answer to question number "<> int.to_string(question),
            fn() {
              components.view_named_keyed_input(
                question,
                name,
                GiveAnswer,
              )
            },
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
            Initial -> html.text("STATUS: Please input your name")
            ReceiveName(_) -> html.text("STATUS: Please validate your name")
            GiveQuestion(_, _) -> html.text("STATUS: Pick question to answer")
            GiveAnswer(_, _, _) -> html.text("STATUS: Give your answer")
            _ -> html.text("STATUS: Waiting for next question")
          },
        ]),
      ]),
    ]),
    terminal_section(model.answers, "[ACTIVE TRANSMISSIONS]", fn(answer) {
      content_cell(answer)
    }),
  ])
}

fn terminal_section(
  answers: List(#(Int, String)),
  header: String,
  extract: fn(#(Int, String)) -> Element(Msg),
) {
  html.div([attribute.class("terminal-section")], [
    html.div([attribute.class("terminal-label mb-4")], [
      html.text(header),
    ]),
    html.div([attribute.class("participants-grid")], list.map(answers, extract)),
  ])
}

fn content_cell(answer: #(Int, String)) -> Element(Msg) {
  let #(question, answer) = answer
  html.div(
    [
      class("participant-box"),
    ],
    [
      html.div([class("participant-name")], [
        html.text("► " <> int.to_string(question)),
      ]),
      html.div([class("participant-answer")], [
        html.text(answer),
      ]),
    ],
  )
}
