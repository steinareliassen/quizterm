import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import shared/message.{type StateControl, SetQuestion}

type State {
  State(questions: List(#(Int, String)))
}

pub fn initialize() {
  actor.new(State([]))
  |> actor.on_message(fn(state: State, message: StateControl) {
    case message {
      SetQuestion(id:, question:) if id >= 0 && id <= 14 -> {
        State(questions: list.key_set(state.questions, id, question))
      }
      // Ignore requests for questions not between 1 and 14.
      message.SetQuestion(_, _) -> state
      message.FetchQuestion(id:, subject:) -> {
        case
          // Find the room, if it exists
          list.key_find(state.questions, id)
        {
          Ok(question) -> actor.send(subject, Some(question))
          Error(_) -> actor.send(subject, option.None)
        }
        state
      }
      message.FetchQuestions(subject) -> {
        actor.send(subject, state.questions)
        state
      }
    }
    |> actor.continue()
  })
  |> actor.start
}
