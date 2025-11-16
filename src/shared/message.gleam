import gleam/option.{type Option}

pub type NotifyServer {
  AnswerQuiz
  RevealAnswer
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
  Lobby(names: List(User))
  Answer
  Await
}

pub type User {
  User(name: String, answer: AnswerStatus)
}
