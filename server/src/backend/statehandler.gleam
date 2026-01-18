import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import group_registry.{type GroupRegistry}
import shared/message.{
  type AnswerStatus, type NotifyClient, Answer, AnswerQuiz, Await, GiveAnswer,
  GiveName, GivenAnswer, HasAnswered, IDontKnow, Lobby, NotAnswered,
  PurgePlayers, RevealAnswer, User,
}

type State {
  State(name_answers: List(#(String, #(Int, AnswerStatus))), hide_answers: Bool)
}

pub fn initialize(registry: GroupRegistry(NotifyClient)) {
  actor.new(State([], True))
  |> actor.on_message(fn(state: State, message) {
    case message {
      message.PingTime(sender) -> {
        broadcast(registry, message.Ping)
        process.send_after(sender, 2000, message.PingTime(sender))

        State(
          ..state,
          // Increase ping count with one,
          // filter away users with more than 4 missed pings first.
          name_answers: list.map(
            list.filter(state.name_answers, fn(user) {
              let #(_, #(count, _)) = user
              count < 4
            }),
            fn(user) {
              let #(name, #(count, stat)) = user
              #(name, #(count + 1, stat))
            },
          ),
        )
        |> broadcast_lobby(registry)
      }
      message.Pong(name) -> {
        // Reset ping count
        case list.key_find(state.name_answers, name) {
          Ok(#(_, answer)) ->
            State(
              ..state,
              name_answers: list.key_set(state.name_answers, name, #(0, answer)),
            )
          Error(_) -> state
        }
      }
      PurgePlayers -> {
        broadcast(registry, message.Exit)
        State([], True)
        |> broadcast_lobby(registry)
      }
      GiveName(name) -> {
        // Let the new client (and everyone else) know the current question state
        case state.hide_answers {
          True -> broadcast(registry, Answer)
          False -> broadcast(registry, Await)
        }
        // Add the new user to lobby, and broadcast lobby
        State(
          list.key_set(state.name_answers, name, #(0, NotAnswered)),
          state.hide_answers,
        )
        |> broadcast_lobby(registry)
      }
      GiveAnswer(name, answer) -> {
        let state =
          State(
            list.key_set(
              state.name_answers,
              name,
              #(0, case answer {
                Some("?") -> IDontKnow
                Some(answer) -> GivenAnswer(answer)
                None -> IDontKnow
              }),
            ),
            state.hide_answers,
          )
        // Check if everyone has answered, if so, reveal answer.
        case
          list.filter(state.name_answers, fn(x) {
            case x {
              #(_, #(_, message.NotAnswered)) -> True
              _ -> False
            }
          })
          |> list.length
        {
          0 -> {
            broadcast(registry, Await)
            State(..state, hide_answers: False)
          }
          _ -> state
        }
        |> broadcast_lobby(registry)
      }
      AnswerQuiz -> {
        broadcast(registry, Answer)
        State(
          list.map(state.name_answers, fn(user) {
            let #(name, #(count, _)) = user
            #(name, #(count, NotAnswered))
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
        let #(name, #(ping_time, answer)) = name_answer
        User(name, ping_time, case answer, state.hide_answers {
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
