import gleam/bit_array
import gleam/crypto
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import group_registry.{type GroupRegistry}
import shared/message.{
  type AnswerStatus, type NotifyClient, type StateControl, Answer, AnswerQuiz,
  Await, GiveAnswer, GiveName, GiveSingleAnswer, GivenAnswer, HasAnswered,
  IDontKnow, Lobby, NotAnswered, PingTime, Pong, PurgePlayers, RevealAnswer,
  User,
}

type State {
  State(
    question_number: Int,
    // id, (name (question#, answer_attempt)
    single_answers: List(#(String, #(String, List(#(String, String))))),
    // int in #pair: ping counted since response back.
    name_answers: List(#(String, #(Int, AnswerStatus))),
    hide_answers: Bool,
    question: option.Option(String),
    state_handler: actor.Started(Subject(StateControl)),
  )
}

pub fn initialize(
  state_handler: actor.Started(Subject(StateControl)),
  registry: GroupRegistry(NotifyClient),
) {
  actor.new(State(1, [], [], True, None, state_handler))
  |> actor.on_message(fn(state: State, message) {
    let question = case state.question {
      None -> {
        case
          actor.call(state_handler.data, 1000, message.FetchQuestion(
            state.question_number,
            _,
          ))
        {
          Some(question) -> question
          None -> "(no question text found)"
        }
      }
      Some(question) -> question
    }

    let state = State(..state, question: Some(question))

    case message {
      // Ask all the clients to let us know they are still there by sending a Pong with their name. Schedule
      // a new ping as well. Count unacced pings per client
      PingTime(sender) -> ping(state, registry, sender)

      // A client has responded to the ping with a pong. Reset the unacced ping count
      Pong(name) -> pong(state, name)

      // (Controller) client asks to remove all players from the board
      PurgePlayers -> purge_players(state, registry)

      // A new player has signed up, put their name in the registry
      GiveName(name) -> give_name(state, registry, name)

      // A player has answered a question, put it in their state. If every player has answered, signal
      // to reveal answers (live game)
      GiveAnswer(name, answer) -> give_answer(state, registry, name, answer)

      // A player has answered a question in "single" game. Register the answer.
      GiveSingleAnswer(id, question, answer) -> {
        State(
          ..state,
          single_answers: case list.key_find(state.single_answers, id) {
            Ok(value) -> {
              let #(name, list) = value
              list.key_set(state.single_answers, id, #(
                name,
                list.key_set(list, question, answer),
              ))
            }
            Error(_) -> {
              state.single_answers
            }
          },
        )
      }
      // Reveal all answers given by players, setting the game in a "wait for next question" mode
      RevealAnswer -> revel_answers(state, registry)

      // Switch from "Wait for next question" to "Answer next question" mode
      AnswerQuiz -> answer_quiz(state, registry)
      message.FetchPlayers(subject:) -> {
        fetch_players(state.single_answers, subject)
        state
      }
      message.AddPlayer(name) ->
        State(..state, single_answers: add_player(name, state.single_answers))
    }
    |> actor.continue()
  })
  |> actor.start
}

fn add_player(name: String, players: List(#(String, #(String, List(#(_, _)))))) {
  let id =
    bit_array.base64_encode(crypto.hash(crypto.Sha256, <<name:utf8>>), True)
  case list.key_find(players, id) {
    Error(_) -> [#(id, #(name, [])), ..players]
    Ok(_) -> players
  }
}

fn fetch_players(
  players: List(#(String, #(String, List(#(String, String))))),
  subject: Subject(List(#(String, #(String, List(#(String, String)))))),
) {
  actor.send(subject, players)
}

// Reschedule a new ping request, and ask clients to ping us back
fn ping(state, registry, sender) {
  broadcast(registry, message.Ping)
  process.send_after(sender, 500, message.PingTime(sender))
  State(
    ..state,
    // Increase ping count with one,
    // filter away users with more than 4 missed pings first.
    name_answers: list.map(
      list.filter(state.name_answers, fn(user) {
        let #(_, #(count, _)) = user
        count < 8
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
  // Tell the clients to switch to "answer quiz" mode
  broadcast(registry, Answer)
  State(
    ..state,
    name_answers: list.map(state.name_answers, fn(user) {
      let #(name, #(count, _)) = user
      #(name, #(count, NotAnswered))
    }),
    question: None,
    question_number: state.question_number + 1,
    hide_answers: True,
  )
  |> broadcast_lobby(registry)
}

fn purge_players(state: State, registry) {
  broadcast(registry, message.Exit)
  State(1, [], [], True, None, state.state_handler)
  |> broadcast_lobby(registry)
}

fn revel_answers(state, registry) {
  // Tell the clients to switch to "view answers" mode
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

// Combine the active player answers with the answers given by the "single" player.
fn combine_lists(state: State) {
  list.append(
    list.map(state.name_answers, fn(name_answer) {
      let #(name, #(ping_time, answer)) = name_answer
      User(name, ping_time, case answer, state.hide_answers {
        GivenAnswer(_), True -> HasAnswered
        GivenAnswer(answer), False -> GivenAnswer(answer)
        other, _ -> other
      })
    }),
    // Second list require a bit more work Iterate over each payers answers,
    // creating user objects where question number match current question number.
    list.flat_map(state.single_answers, fn(name_answers) {
      let #(_, #(name, answers)) = name_answers
      list.filter_map(answers, fn(number_answer) {
        let #(answer_number, answer) = number_answer
        case int.to_string(state.question_number) == answer_number {
          True -> {
            Ok(
              User(name, 0, case state.hide_answers {
                True -> HasAnswered
                False -> GivenAnswer(answer)
              }),
            )
          }
          False -> Error("ignore")
        }
      })
    }),
  )
}

fn broadcast_lobby(state: State, registry: GroupRegistry(NotifyClient)) {
  broadcast(
    registry,
    Lobby(
      "Question "
        <> int.to_string(state.question_number)
        <> ": "
        <> case state.question {
        Some(question) -> question
        None -> "(question not found)"
      },
      combine_lists(state),
    ),
  )

  state
}

fn broadcast(registry: GroupRegistry(msg), msg) -> Nil {
  use member <- list.each(group_registry.members(registry, "quiz"))

  process.send(member, msg)
}
