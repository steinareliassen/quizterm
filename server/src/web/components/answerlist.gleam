import components.{click_cell_pair}
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Started}
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import lustre/server_component
import shared/message

pub opaque type Model {
  Model(
    player_name: String,
    state: Msg,
    answers: List(#(String, #(String, String))),
    handler: Started(Subject(message.NotifyServer)),
  )
}

pub opaque type Msg {
  PickQuestion
  PickedQuestion(question: Option(#(String, String)))
  GiveAnswer(question: #(String, String), answer: Option(String))
}

pub fn init(
  name: String,
  answer_list: List(#(String, String)),
  handler: Started(Subject(message.NotifyServer)),
) {
  // Convert a "question number -> question text" array to
  // "question number" -> #("question text", "users answer" array
  // with blank user answers.
  let initial_array =
    list.map(answer_list, fn(x) {
      let #(a, b) = x
      #(a, #(b, ""))
    })

  Model(name, PickQuestion, initial_array, handler)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    PickedQuestion(Some(question)) -> {
      Model(..model, state: GiveAnswer(question:, answer: None))
    }
    GiveAnswer(question, Some(answer)) -> {
      let #(question, _) = question
      actor.send(
        model.handler.data,
        message.GiveSingleAnswer(id: model.player_name, question:, answer:),
      )
      let new_value = case list.key_find(model.answers, question) {
        Ok(pair) -> {
          let #(a, _) = pair
          #(a, answer)
        }
        Error(_) -> #("", answer)
      }
      Model(
        ..model,
        state: PickQuestion,
        answers: list.key_set(model.answers, question, new_value),
      )
    }
    // Invalid states and "I want to start over" states.
    GiveAnswer(_, None) | PickedQuestion(None) | PickQuestion ->
      Model(..model, state: PickQuestion)
  }
}

pub fn view(model: Model) -> Element(Msg) {
  element.fragment([
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.text(" SYSTEM READY"),
        html.div([class("ml-8")], [
          case model.state {
            PickQuestion -> html.text("STATUS: Pick question to answer")
            GiveAnswer(_, _) -> html.text("STATUS: Give your answer")
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
        PickQuestion -> view_questions(model.answers)
        GiveAnswer(answer, None) -> input_new_answer(answer)
        _ -> content_cell(#(10, #("Answer", "Answer question")))
      },
    ]),
  ])
}

fn input_new_answer(question: #(String, String)) {
  let #(question_id, question_text) = question
  html.div([class("participant-box")], [
    input_cell("Answer [" <> question_id <> "] " <> question_text, GiveAnswer(
      question,
      _,
    )),
  ])
}

fn view_questions(answers: List(#(String, #(String, String)))) {
  html.div([], [
    html.div(
      [class("singles-grid")],
      list.map(answers, fn(content) {
        let #(number, #(question, answer)) = content
        click_cell_pair(
          Some(number <> " " <> answer),
          Some(#(number, question)),
          True,
          PickedQuestion,
        )
      }),
    ),
    html.div([], [
      html.text(
        "[Your answers are saved automatically, when you are done answering, simply close the window]",
      ),
    ]),
  ])
}

fn content_cell(answer: #(Int, #(String, String))) -> Element(Msg) {
  let #(question, #(question_text, answer)) = answer
  html.div(
    [
      class("participant-box"),
    ],
    [
      html.div([class("participant-name")], [
        html.text("► " <> int.to_string(question) <> " " <> question_text),
      ]),
      html.div([class("participant-answer")], [
        html.text(answer),
      ]),
    ],
  )
}

fn input_cell(
  text: String,
  on_submit handle_keydown: fn(Option(String)) -> msg,
) -> Element(msg) {
  html.div([attribute.class("singles-grid")], [
    html.div([], [html.text(text)]),
    keyed.div([], [
      #("inputheader", html.text("$>")),
      #(
        "input",
        html.input([
          attribute.type_("text"),
          key_down(
            fn(a: String) { decode.success(handle_keydown(Some(a))) },
            fn() { decode.failure(handle_keydown(None), "") },
          ),
          attribute.autofocus(True),
        ]),
      ),
    ]),
  ])
}

fn key_down(
  success: fn(String) -> decode.Decoder(msg),
  fail: fn() -> decode.Decoder(msg),
) {
  event.on("keydown", {
    use key <- decode.field("key", decode.string)
    use value <- decode.subfield(["target", "value"], decode.string)

    case key {
      "Enter" if value != "" -> success(value)
      _ -> fail()
    }
  })
  |> server_component.include(["key", "target.value"])
}
