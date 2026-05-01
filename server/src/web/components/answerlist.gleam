import components.{click_cell, content_cell, terminal_header}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Started}
import gleam/string
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import shared/message
import web/components/shared.{input_cell}

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
  GiveAnswer(question: #(String, String), answer: String)
}

pub fn init(
  name: String,
  answer_list: List(#(String, String)),
  handler: Started(Subject(message.NotifyServer)),
) {
  let previous_answers =
    actor.call(handler.data, 2000, message.FetchPlayerAnswers(name, _))
  // Convert a "question number -> question text" array to
  // "question number" -> #("question text", "users answer" array
  // with blank user answers. Add previous answers into list.
  let initial_array =
    list.map(answer_list, fn(x) {
      let #(a, b) = x
      #(
        a,
        #(b, case list.key_find(previous_answers, a) {
          Error(_) -> ""
          Ok(previous_answer) -> previous_answer
        }),
      )
    })

  Model(name, PickQuestion, initial_array, handler)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    PickedQuestion(Some(question)) -> {
      Model(..model, state: GiveAnswer(question:, answer: ""))
    }
    GiveAnswer(question, answer) -> {
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
    PickedQuestion(None) | PickQuestion -> Model(..model, state: PickQuestion)
  }
}

pub fn view(model: Model) -> Element(Msg) {
  element.fragment([
    case model.state {
      PickQuestion -> html.text("STATUS: Pick question to answer")
      GiveAnswer(_, _) -> html.text("STATUS: Give your answer")
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
        PickQuestion -> view_questions(model.answers)
        GiveAnswer(answer, "") -> input_new_answer(answer)
        _ ->
          content_cell("►  [ Answer ]", Some("Answer question"), components.Box)
      },
    ]),
  ])
}

fn input_new_answer(question: #(String, String)) {
  let #(question_id, question_text) = question
  html.div([class("participant-box")], [
    input_cell(
      " ► Answer [" <> question_id <> "] " <> question_text,
      GiveAnswer(question, _),
    ),
  ])
}

fn view_questions(answers: List(#(String, #(String, String)))) {
  html.div([], [
    html.div(
      [class("singles-grid")],
      list.map(answers, fn(content) {
        let #(number, #(question, answer)) = content

        click_cell(
          Some(#(number, question)),
          PickedQuestion,
          Some("[#" <> number <> "] " <> answer),
          Some(question),
          case string.length(answer) > 0 {
            False -> components.Name
            True -> components.Answer
          },
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

