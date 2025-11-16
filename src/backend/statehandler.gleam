import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import group_registry.{type GroupRegistry}
import shared/message.{
  type AnswerStatus, type NotifyClient, Answer, AnswerQuiz, Await, GiveAnswer,
  GiveName, GivenAnswer, HasAnswered, IDontKnow, Lobby, NotAnswered,
  RevealAnswer, User,
}

type State {
  State(name_answers: List(#(String, AnswerStatus)), hide_answers: Bool)
}

pub fn initialize(registry: GroupRegistry(NotifyClient)) {
  actor.new(State([], True))
  |> actor.on_message(fn(state: State, message) {
    case message {
      GiveName(name) -> {
        // Let the new client (and everyone else) know the current question state
        case state.hide_answers {
          True -> broadcast(registry, Answer)
          False -> broadcast(registry, Await)
        }
        // Add the new user to lobby, and broadcast lobby
        State(
          list.key_set(state.name_answers, name, NotAnswered),
          state.hide_answers,
        )
        |> broadcast_lobby(registry)
      }
      GiveAnswer(name, answer) -> {
        State(
          list.key_set(state.name_answers, name, case answer {
            Some("?") -> IDontKnow
            Some(answer) -> GivenAnswer(answer)
            None -> IDontKnow
          }),
          state.hide_answers,
        )
        |> broadcast_lobby(registry)
      }
      AnswerQuiz -> {
        broadcast(registry, Answer)
        State(
          list.map(state.name_answers, fn(user) {
            let #(name, _) = user
            #(name, NotAnswered)
          }),
          hide_answers: True,
        )
        |> broadcast_lobby(registry)
      }
      RevealAnswer -> {
        broadcast(registry, Await)
        State(state.name_answers, hide_answers: False)
        |> broadcast_lobby(registry)
      }
    }
    |> actor.continue()
  })
  |> actor.start
}

fn broadcast_lobby(state: State, registry: GroupRegistry(NotifyClient)) {
  broadcast(
    registry,
    Lobby(
      list.map(state.name_answers, fn(name_answer) {
        let #(name, answer) = name_answer
        User(name, case answer, state.hide_answers {
          GivenAnswer(_), True -> HasAnswered
          GivenAnswer(answer), False -> GivenAnswer(answer)
          other, _ -> other
        })
      }),
    ),
  )

  state
}

fn broadcast(registry: GroupRegistry(msg), msg) -> Nil {
  use member <- list.each(group_registry.members(registry, "quiz"))

  process.send(member, msg)
}
