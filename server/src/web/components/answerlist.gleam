import components.{click_cell_pair}
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Started}
import lustre
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import lustre/server_component
import shared/message.{type NotifyClient, type NotifyServer}
import web/components/shared

pub fn component() -> lustre.App(
  #(List(#(String, String)), message.ClientsServer),
  Model,
  Msg,
) {
  lustre.application(init, update, view)
}

pub opaque type Model {
  Model(
    state: Msg,
    players: List(#(String, #(String, List(#(String, String))))),
    player: Option(#(String, String)),
    answers: List(#(String, #(String, String))),
    handler: Started(Subject(NotifyServer)),
  )
}

pub opaque type Msg {
  Initial
  PickedPlayer(player: Option(#(String, String)))
  SharedMessage(message: NotifyClient)
  ReceiveName(name: Option(String))
  AcceptPlayer(accept: Option(#(String, String)))
  PickQuestion
  PickedQuestion(question: Option(#(String, String)))
  GiveAnswer(question: #(String, String), answer: Option(String))
}

fn init(
  start_args: #(List(#(String, String)), message.ClientsServer),
) -> #(Model, Effect(Msg)) {
  let #(answers, handlers) = start_args
  let #(_registry, handler) = handlers

  // Convert a "question number -> question text" array to
  // "question number" -> #("question text", "users answer" array
  // with blank user answers.
  let initial_array =
    list.map(answers, fn(x) {
      let #(a, b) = x
      #(a, #(b, ""))
    })

  #(
    Model(
      Initial,
      actor.call(handler.data, 1000, message.FetchPlayers),
      None,
      initial_array,
      handler,
    ),
    effect.none(),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Initial -> #(Model(..model, state: msg), effect.none())
    PickedPlayer(player) -> #(
      case player {
        Some(player) -> Model(..model, state: AcceptPlayer(Some(player)))
        None -> Model(..model, state: ReceiveName(None))
      },
      effect.none(),
    )

    SharedMessage(_) -> #(model, effect.none())
    ReceiveName(Some(name)) -> {
      let id =
        bit_array.base64_encode(crypto.hash(crypto.Sha256, <<name:utf8>>), True)
      #(Model(..model, state: AcceptPlayer(Some(#(id, name)))), effect.none())
    }
    AcceptPlayer(Some(player)) -> {
      let #(_, player_name) = player
      actor.send(model.handler.data, message.AddPlayer(player_name))
      #(
        Model(..model, player: Some(player), state: PickQuestion),
        effect.none(),
      )
    }
    PickedQuestion(Some(question)) -> {
      #(
        Model(..model, state: GiveAnswer(question:, answer: None)),
        effect.none(),
      )
    }
    GiveAnswer(question, Some(answer)) -> {
      let #(question, _) = question
      let assert Some(#(player_id, _)) = model.player
      actor.send(
        model.handler.data,
        message.GiveSingleAnswer(id: player_id, question:, answer:),
      )
      let new_value = case list.key_find(model.answers, question) {
        Ok(pair) -> {
          let #(a, _) = pair
          #(a, answer)
        }
        Error(_) -> #("", answer)
      }
      #(
        Model(
          ..model,
          state: PickQuestion,
          answers: list.key_set(model.answers, question, new_value),
        ),
        effect.none(),
      )
    }
    // Invalid states and "I want to start over" states|
    GiveAnswer(_, None)
    | AcceptPlayer(None)
    | ReceiveName(None)
    | PickedQuestion(None)
    | PickQuestion -> #(
      Model(Initial, model.players, None, model.answers, model.handler),
      effect.none(),
    )
  }
}

fn view(model: Model) -> Element(Msg) {
  element.fragment([
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.text(" SYSTEM READY"),
        html.div([class("ml-8")], [
          case model.state {
            Initial -> html.text("STATUS: Please select player")
            ReceiveName(_) -> html.text("STATUS: Please enter your name")
            PickQuestion -> html.text("STATUS: Pick question to answer")
            GiveAnswer(_, _) -> html.text("STATUS: Give your answer")
            AcceptPlayer(_) -> html.text("STATUS: Validate player")
            _ -> html.text("STATUS: Waiting for next question")
          },
        ]),
      ]),
    ]),
    html.div([attribute.class("terminal-section")], [
      html.div([attribute.class("terminal-label mb-4")], [
        html.text("[ACTIVE TRANSMISSIONS]"),
      ]),
    ]),
    html.div([class("participants-grid")], [
      case model.state {
        Initial ->
          case model.players {
            [] -> shared.input_new_player(ReceiveName)
            _ ->
              shared.view_players(
                list.map(model.players, fn(player) {
                  let #(id, #(name, _)) = player
                  #(id, name)
                }),
                PickedPlayer,
              )
          }
        PickQuestion -> view_questions(model.answers)
        ReceiveName(_) -> shared.input_new_player(ReceiveName)
        AcceptPlayer(Some(player)) -> {
          let #(_, player_name) = player
          shared.confirm_cells(
            Some("Join as this player: " <> player_name <> "?"),
            player,
            AcceptPlayer,
          )
        }
        GiveAnswer(answer, None) -> input_new_answer(answer)

        _ -> content_cell(#(10, #("Answer", "Answer question")))
      },
    ]),
  ])
}

fn input_new_answer(question: #(String, String)) {
  let #(question_id, question_text) = question
  html.div([class("participant-box")], [
    input_cell("Answer [" <> question_id <> "] " <> question_text, GiveAnswer(
      question,
      _,
    )),
  ])
}

fn view_questions(answers: List(#(String, #(String, String)))) {
  html.div([], [
    html.div(
      [class("singles-grid")],
      list.map(answers, fn(content) {
        let #(number, #(question, answer)) = content
        click_cell_pair(
          Some(number <> " " <> answer),
          Some(#(number, question)),
          True,
          PickedQuestion,
        )
      }),
    ),
    html.div([], [
      html.text(
        "[Your answers are saved automatically, when you are done answering, simply close the window]",
      ),
    ]),
  ])
}

fn content_cell(answer: #(Int, #(String, String))) -> Element(Msg) {
  let #(question, #(question_text, answer)) = answer
  html.div(
    [
      class("participant-box"),
    ],
    [
      html.div([class("participant-name")], [
        html.text("► " <> int.to_string(question) <> " " <> question_text),
      ]),
      html.div([class("participant-answer")], [
        html.text(answer),
      ]),
    ],
  )
}

fn input_cell(
  text: String,
  on_submit handle_keydown: fn(Option(String)) -> msg,
) -> Element(msg) {
  html.div([attribute.class("singles-grid")], [
    html.div([], [html.text(text)]),
    keyed.div([], [
      #("inputheader", html.text("$>")),
      #(
        "input",
        html.input([
          attribute.type_("text"),
          key_down(
            fn(a: String) { decode.success(handle_keydown(Some(a))) },
            fn() { decode.failure(handle_keydown(None), "") },
          ),
          attribute.autofocus(True),
        ]),
      ),
    ]),
  ])
}

fn key_down(
  success: fn(String) -> decode.Decoder(msg),
  fail: fn() -> decode.Decoder(msg),
) {
  event.on("keydown", {
    use key <- decode.field("key", decode.string)
    use value <- decode.subfield(["target", "value"], decode.string)

    case key {
      "Enter" if value != "" -> success(value)
      _ -> fail()
    }
  })
  |> server_component.include(["key", "target.value"])
}
