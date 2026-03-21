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
  State(
    slow_answers: List(#(String, #(Int, String))),
    name_answers: List(#(String, #(Int, AnswerStatus))),
    hide_answers: Bool,
  )
}

pub fn initialize(registry: GroupRegistry(NotifyClient)) {
  actor.new(State([], [], True))
  |> actor.on_message(fn(state: State, message) {
    case message {
      // Ask all the clients to let us know they are still there by sending a Pong with their name. Schedule
      // a new ping as well. Count unacced pings per client
      message.PingTime(sender) -> ping(state, registry, sender)

      // A client has responded to the ping with a pong. Reset the unacced ping count
      message.Pong(name) -> pong(state, name)

      // (Controller) client asks to remove all players from the board
      PurgePlayers -> purge_players(registry)

      // A new player has signed up, put their name in the registry
      GiveName(name) -> give_name(state, registry, name)

      // A player has answered a question, put it in their state. If every player has answered, signal
      // to reveal answers
      GiveAnswer(name, answer) -> give_answer(state, registry, name, answer)

      // Reveal all answers given by players, setting the game in a "wait for next question" mode
      RevealAnswer -> revel_answers(state, registry)

      // Switch from "Wait for next question" to "Answer next question" mode
      AnswerQuiz -> answer_quiz(state, registry)
    }
    |> actor.continue()
  })
  |> actor.start
}

// Reschedule a new ping request, and ask clients to ping us back
fn ping(state, registry, sender) {
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

fn give_answer(state, registry, name, answer) {
  let state =
    State(
      ..state,
      name_answers: list.key_set(
        state.name_answers,
        name,
        #(0, case answer {
          Some("?") -> IDontKnow
          Some(answer) -> GivenAnswer(answer)
          None -> IDontKnow
        }),
      ),
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

fn give_name(state: State, registry, name) {
  // Let the new client (and everyone else) know the current question state
  case state.hide_answers {
    True -> broadcast(registry, Answer)
    False -> broadcast(registry, Await)
  }
  // Add the new user to lobby, and broadcast lobby
  State(
    ..state,
    name_answers: list.key_set(state.name_answers, name, #(0, NotAnswered)),
  )
  |> broadcast_lobby(registry)
}

fn answer_quiz(state, registry) {
  broadcast(registry, Answer)
  State(
    ..state,
    name_answers: list.map(state.name_answers, fn(user) {
      let #(name, #(count, _)) = user
      #(name, #(count, NotAnswered))
    }),
    hide_answers: True,
  )
  |> broadcast_lobby(registry)
}

fn purge_players(registry) {
  broadcast(registry, message.Exit)
  State([], [], True)
  |> broadcast_lobby(registry)
}

fn revel_answers(state, registry) {
  broadcast(registry, Await)
  State(..state, hide_answers: False)
  |> broadcast_lobby(registry)
}

fn pong(state: State, name) {
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
