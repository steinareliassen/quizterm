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
  GiveSingleAnswer(id: String, question: String, answer: String)
  FetchPlayers(subject: Subject(List(String)))
  FetchAllAnswers(subject: Subject(List(#(Int, List(#(String, String))))))
  FetchPlayerAnswers(player: String, subject: Subject(List(#(String, String))))
  AddPlayer(String)
}

pub type StateControl {
  SetQuestion(id: Int, question: String)
  SetAnswer(id: Int, answer: String)
  SetInfo(url: String)
  FetchQuestion(id: Int, subject: Subject(Option(String)))
  FetchQuestions(subject: Subject(List(#(String, String))))
}

pub type Room {
  Room(name: String, pin_enc: String, room_key: Option(String), actors: ClientsServer)
}

pub type RoomInfo {
  RoomInfo(name: String, pin_enc: String, room_key: Option(String))
}

pub type RoomControl {
  CreateRoom(id: String, room: RoomInfo)
  FetchRoom(id: String, subject: Subject(Option(ClientsServer)))
  FetchRoomChecked(id: String, pin_or_key: String, is_pin: Bool,subject: Subject(Option(ClientsServer)))
  FetchRooms(subject: Subject(List(#(String, RoomInfo))))
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
}

pub type User {
  User(name: String, ping_time: Int, answer: AnswerStatus)
}
