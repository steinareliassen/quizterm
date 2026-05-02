import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

type State {
  State(uri: Option(String), questions: List(#(Int, #(String, String))))
}

pub type StateControl {
  SetQuestion(id: Int, question: String)
  SetAnswer(id: Int, answer: String)
  SetInfo(url: String)
  FetchQuestion(id: Int, subject: Subject(Option(String)))
  FetchQuestions(subject: Subject(List(#(String, String))))
}

pub fn initialize() {
  actor.new(State(None, []))
  |> actor.on_message(fn(state: State, message: StateControl) {
    case message {
      SetQuestion(id:, question:) if id >= 0 && id <= 14 -> {
        case list.key_find(state.questions, id) {
          Ok(#(_, answer)) ->
            State(
              ..state,
              questions: list.key_set(state.questions, id, #(question, answer)),
            )
          Error(_) ->
            State(
              ..state,
              questions: list.key_set(state.questions, id, #(
                question,
                "not provided",
              )),
            )
        }
      }
      SetAnswer(id:, answer:) if id >= 0 && id <= 14 ->
        case list.key_find(state.questions, id) {
          Ok(#(question, _)) ->
            State(
              ..state,
              questions: list.key_set(state.questions, id, #(question, answer)),
            )
          Error(_) ->
            State(
              ..state,
              questions: list.key_set(state.questions, id, #(
                "not provided",
                answer,
              )),
            )
        }

      // Ignore requests for questions/answers not between 1 and 14.
      SetQuestion(_, _) | SetAnswer(_, _) -> state
      FetchQuestion(id:, subject:) -> {
        case
          // Find the room, if it exists
          list.key_find(state.questions, id)
        {
          Ok(#(question, _)) -> actor.send(subject, Some(question))
          Error(_) -> actor.send(subject, option.None)
        }
        state
      }
      SetInfo(uri) -> State(..state, uri: Some(uri))
      FetchQuestions(subject) -> {
        actor.send(
          subject,
          list.map(state.questions, fn(x) {
            let #(i, #(q, _)) = x
            #(int.to_string(i), q)
          }),
        )
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}
