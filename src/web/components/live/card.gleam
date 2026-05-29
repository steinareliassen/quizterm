import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/server_component
import shared/message.{type User, User}
import web/components.{content_cell, key_down, terminal_header}
import web/components/live/model.{
  type Model, type Msg, Answer, GiveAnswer, Init, Model, SharedMessage, Wait,
}

pub fn update(model: Model, msg: Msg) -> Model {
  let handler = model.handler

  case msg {
    GiveAnswer(answer) -> {
      actor.send(handler, message.GiveAnswer(model.name, Some(answer)))
      Model(..model, state: Wait)
    }
    SharedMessage(shared_msg) -> handle_server_message(model, shared_msg)
  }
}

fn handle_server_message(model: Model, notify_client) {
  case notify_client {
    message.Lobby(question, lobby) -> Model(..model, lobby: #(question, lobby))
    message.Answer -> Model(..model, state: Answer)
    message.Await -> Model(..model, state: Wait)
    message.Ping -> {
      actor.send(model.handler, message.Pong(model.name))
      model
    }
  }
}

pub fn view_2(model: Model) -> Element(Msg) {
  let #(question, users) = model.lobby
  element.fragment([
    case model.state {
      Answer ->
        html.div([], [
          html.div([], [html.text("STATUS: Answer the following:")]),
          html.div([], [html.text(question)]),
        ])
      _ -> html.text("STATUS: Waiting for next question")
    }
      |> terminal_header(Some(""), _),
    case model.state {
      Init -> {
        actor.send(model.handler, message.GiveName(model.name))
        html.div([attribute.class("terminal-section")], [
          html.h3([], [html.text("Registered user, waiting in lobby")]),
        ])
      }
      Answer -> {
        html.div([attribute.class("terminal-section")], [
          [view_input(GiveAnswer)] |> components.div_styled(components.Box),
        ])
      }
      _ -> {
        html.div([attribute.class("terminal-section")], [
          html.h3([], [html.text("Waiting for next question")]),
        ])
      }
    },
    element.fragment([
      html.div([class("terminal-section")], case users {
        [] -> []
        users -> {
          let answered = count_answered(users)
          let size = users |> list.length |> int.to_string
          [
            html.div([attribute.class("terminal-box")], [
              html.span([attribute.class("terminal-label")], [
                html.text("[PROGRESS] "),
              ]),
              html.text("Answered: "),
              case answered == size {
                True -> html.text("Everyone!")
                False -> html.text(answered <> "/" <> size)
              },
            ]),
          ]
        }
      }),
      terminal_section(
        users,
        "[ACTIVE TRANSMISSIONS]",
        fn(x) {
          case x.answer {
            message.GivenAnswer(_) | message.HasAnswered -> True
            _ -> False
          }
        },
        fn(user) {
          let User(name, ping_time, answer) = user
          case answer {
            message.GivenAnswer(answer) -> Some(answer)
            message.HasAnswered -> Some("Answer Given")
            _ -> Some("Odd State...")
          }
          |> content_cell("► " <> name, _, ping_to_style(ping_time))
        },
      ),
      terminal_section(
        users,
        "[P A S S]",
        fn(x) {
          case x.answer {
            message.IDontKnow -> True
            _ -> False
          }
        },
        fn(user) {
          let User(name, ping_time, _) = user
          content_cell(
            "► " <> name,
            Some("P.A.S.S. :("),
            ping_to_style(ping_time),
          )
        },
      ),
      terminal_section(
        users,
        "[AWAITING RESPONSE]",
        fn(x) {
          case x.answer {
            message.NotAnswered -> True
            _ -> False
          }
        },
        fn(user) {
          case user {
            User(name, ping_time, _) ->
              content_cell(
                "► " <> name,
                Some("Not answered"),
                ping_to_style(ping_time),
              )
          }
        },
      ),
      server_component.element(
        [
          server_component.route(
            "/socket/control/" <> model.team_id <> "/" <> model.team_pin,
          ),
        ],
        [],
      ),
    ]),
  ])
}

pub fn view(model: Model) -> Element(Msg) {
  let #(question, users) = model.lobby
  element.fragment([
    case model.state {
      Answer -> {
        html.div([attribute.class("terminal-section")], [
          [
            html.div([], [html.text(question)]),
            html.div([], [view_input(GiveAnswer)]),
          ]
          |> components.div_styled(components.Login),
        ])
      }
      _ -> {
        html.div([attribute.class("terminal-section")], [
          html.h3([], [html.text("Waiting question")]),
        ])
      }
    },
    element.fragment([
      html.div([class("terminal-section")], case users {
        [] -> []
        users -> {
          let answered = count_answered(users)
          let size = users |> list.length |> int.to_string
          [
            html.div([attribute.class("terminal-box")], [
              html.span([attribute.class("terminal-label")], [
                html.text("[PROGRESS] "),
              ]),
              html.text("Answered: "),
              case answered == size {
                True -> html.text("Everyone!")
                False -> html.text(answered <> "/" <> size)
              },
            ]),
          ]
        }
      }),
      terminal_section(
        users,
        "[ACTIVE TRANSMISSIONS]",
        fn(x) {
          case x.answer {
            message.GivenAnswer(_) | message.HasAnswered -> True
            _ -> False
          }
        },
        fn(user) {
          let User(name, ping_time, answer) = user
          case answer {
            message.GivenAnswer(answer) -> Some(answer)
            message.HasAnswered -> Some("Answer Given")
            _ -> Some("Odd State...")
          }
          |> content_cell("► " <> name, _, ping_to_style(ping_time))
        },
      ),
      terminal_section(
        users,
        "[P A S S]",
        fn(x) {
          case x.answer {
            message.IDontKnow -> True
            _ -> False
          }
        },
        fn(user) {
          let User(name, ping_time, _) = user
          content_cell(
            "► " <> name,
            Some("P.A.S.S. :("),
            ping_to_style(ping_time),
          )
        },
      ),
      terminal_section(
        users,
        "[AWAITING RESPONSE]",
        fn(x) {
          case x.answer {
            message.NotAnswered -> True
            _ -> False
          }
        },
        fn(user) {
          case user {
            User(name, ping_time, _) ->
              content_cell(
                "► " <> name,
                Some("Not answered"),
                ping_to_style(ping_time),
              )
          }
        },
      ),
      server_component.element(
        [
          server_component.route(
            "/socket/control/" <> model.team_id <> "/" <> model.team_pin,
          ),
        ],
        [],
      ),
    ]),
  ])
}

fn ping_to_style(ping_time: Int) {
  case ping_time > 1 {
    True -> components.Disconnect
    False -> components.Box
  }
}

fn terminal_section(
  lobby: List(User),
  header: String,
  filter: fn(User) -> Bool,
  extract: fn(User) -> Element(Msg),
) {
  html.div([attribute.class("terminal-section")], [
    html.div([attribute.class("terminal-label mb-4")], [
      html.text(header),
    ]),
    html.div(
      [attribute.class("participants-grid")],
      list.filter(lobby, filter)
        |> list.map(extract),
    ),
  ])
}

pub fn view_input(on_submit handle_keydown: fn(String) -> msg) -> Element(msg) {
  // Why keyed? See: https://hexdocs.pm/lustre/lustre/element/keyed.html
  keyed.div([], [
    #("inputheader", html.text("► ")),
    #(
      "input",
      html.input([
        attribute.type_("text"),
        key_down(fn(a: String) { decode.success(handle_keydown(a)) }, fn() {
          decode.failure(handle_keydown(""), "")
        }),
        attribute.autofocus(True),
      ]),
    ),
  ])
}

fn step_prompt(text: String, fetch: fn() -> Element(a)) {
  html.div([attribute.class("prompt-line")], [
    html.div([attribute.class("prompt-text")], [
      html.div([], [
        html.text(text),
      ]),
      fetch(),
    ]),
  ])
}

fn count_answered(users: List(User)) {
  list.filter(users, fn(x) {
    case x.answer {
      message.IDontKnow | message.HasAnswered | message.GivenAnswer(_) -> True
      _ -> False
    }
  })
  |> list.length
  |> int.to_string
}
