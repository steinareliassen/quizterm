import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import group_registry.{type GroupRegistry}
import shared/message.{
  type NotifyClient, Answer, AnswerQuiz, Await, GiveAnswer, GiveName, Lobby,
  RevealAnswer, User,
}

type State {
  State(name_answers: List(#(String, Option(String))), hide_answers: Bool)
}

pub fn initialize(registry: GroupRegistry(NotifyClient)) {
  actor.new(State([], True))
  |> actor.on_message(fn(state: State, message) {
    case message {
      GiveName(name) -> {
        // Let the new client know the current question state
        case state.hide_answers {
          True -> broadcast(registry, Answer)
          False -> broadcast(registry, Await)
        }
        State(list.key_set(state.name_answers, name, None), state.hide_answers)
        |> broadcast_lobby(registry)
      }
      GiveAnswer(name, answer) -> {
        State(
          list.key_set(state.name_answers, name, Some(answer)),
          state.hide_answers,
        )
        |> broadcast_lobby(registry)
      }
      AnswerQuiz -> {
        broadcast(registry, Answer)
        State(
          list.map(state.name_answers, fn(user) {
            let #(name, _) = user
            #(name, None)
          }),
          True,
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
        User(name, case answer {
          Some(answer) ->
            Some(case state.hide_answers {
              True -> "Answer"
              False -> answer
            })
          None ->
            case state.hide_answers {
              True -> None
              False -> Some("No answer")
            }
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
