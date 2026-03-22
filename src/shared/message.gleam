import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/otp/actor.{type Started}
import group_registry.{type GroupRegistry}

pub type ClientsServer =
  #(GroupRegistry(NotifyClient), Started(Subject(NotifyServer)))

pub type NotifyServer {
  PingTime(Subject(NotifyServer))
  Pong(name: String)
  AnswerQuiz
  RevealAnswer
  PurgePlayers
  GiveName(name: String)
  GiveAnswer(name: String, answer: Option(String))
}

pub type StateControl {
  SetQuestion(id: Int, question: String)
  FetchQuestion(id: Int, subject: Subject(Option(String)))
  FetchQuestions(subject: Subject(List(#(Int, String))))
}

pub type RoomControl(msg) {
  CreateRoom(id: String)
  FetchRoom(id: String, subject: Subject(Option(msg)))
}

pub type AnswerStatus {
  NotAnswered
  HasAnswered
  IDontKnow
  GivenAnswer(answer: String)
}

pub type NotifyClient {
  Ping
  Lobby(question: String, names: List(User))
  Answer
  Await
  Exit
}

pub type User {
  User(name: String, ping_time: Int, answer: AnswerStatus)
}
