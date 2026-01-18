import gleam/dynamic/decode
import gleam/json

pub type AnswerRequest {
  AnswerRequest(key: String, user: String,  question: Int, answer: String)
}

pub type AnswerResponse {
  AnswerResponse(question: Int, answer: String)
}

fn objectify_answer_request() -> decode.Decoder(AnswerRequest) {
  use key <- decode.field("key", decode.string)
  use user <- decode.field("user", decode.string)
  use question <- decode.field("question", decode.int)
  use answer <- decode.field("answer", decode.string)
  decode.success(AnswerRequest(key:, user:, question:, answer:))
}

fn jsonify_answer_request(answer: AnswerRequest) -> json.Json {
  let AnswerRequest(key:, user:, question:, answer:) = answer
  json.object([
    #("key", json.string(key)),
    #("user", json.string(user)),
    #("question", json.int(question)),
    #("answer", json.string(answer)),
  ])
}

fn objectify_answer_response() -> decode.Decoder(AnswerResponse) {
  use question <- decode.field("question", decode.int)
  use answer <- decode.field("answer", decode.string)
  decode.success(AnswerResponse(question:, answer:))
}

fn jsonify_answer_response(answer: AnswerResponse) -> json.Json {
  let AnswerResponse(question:, answer:) = answer
  json.object([
    #("question", json.int(question)),
    #("answer", json.string(answer)),
  ])
}

pub fn objectify_answer_responses() -> decode.Decoder(List(AnswerResponse)) {
  decode.list(objectify_answer_response())
}

pub fn jsonify_answers(items: List(AnswerResponse)) -> json.Json {
  json.array(items, jsonify_answer_response)
}
