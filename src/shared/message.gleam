import gleam/option.{type Option}

pub type NotifyServer {
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
  Lobby(names: List(User))
  Answer
  Await
}

pub type User {
  User(name: String, answer: AnswerStatus)
}
