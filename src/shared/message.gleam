import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}

pub type NotifyServer {
  PingTime(Subject(NotifyServer))
  Pong(name: String)
  AnswerQuiz
  RevealAnswer
  PurgePlayers
  GiveName(name: String)
  GiveAnswer(name: String, answer: Option(String))
}

pub type AnswerStatus {
  NotAnswered
  HasAnswered
  IDontKnow
  GivenAnswer(answer: String)
}

pub type NotifyClient {
  Exit
  Ping
  Lobby(names: List(User))
  Answer
  Await
}

pub type User {
  User(name: String, ping_time: Int, answer: AnswerStatus)
}
