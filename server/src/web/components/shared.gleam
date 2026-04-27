import components.{Name, click_cell}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import lustre/server_component

// Components use "keyed.div" rather than "html.div" for input fields
// The value of the fields are uncontrolled, so this is needed to
// get a new state between each input, or else the value transfers between
// input fields.
//
// see: https://hexdocs.pm/lustre/lustre/element/keyed.html

pub fn view_named_keyed_input(
  question: Int,
  name: String,
  on_submit handle_keydown: fn(String, Int, String) -> msg,
) -> Element(msg) {
  prompt_input(
    "keyput",
    key_down(
      fn(a: String) { decode.success(handle_keydown(name, question, a)) },
      fn() { decode.failure(handle_keydown(name, question, ""), "") },
    ),
  )
}

pub fn view_input(on_submit handle_keydown: fn(String) -> msg) -> Element(msg) {
  prompt_input(
    "input",
    key_down(fn(a: String) { decode.success(handle_keydown(a)) }, fn() {
      decode.failure(handle_keydown(""), "")
    }),
  )
}

fn prompt_input(key, on_keydown) {
  keyed.div([], [
    #(key <> "header", html.text("$>")),
    #(
      key,
      html.input([
        attribute.type_("text"),
        on_keydown,
        attribute.autofocus(True),
      ]),
    ),
  ])
}

pub fn step_prompt(text: String, fetch: fn() -> Element(a)) {
  html.div([attribute.class("prompt-line")], [
    html.div([attribute.class("prompt-text")], [
      html.div([], [
        html.text(text),
      ]),
      fetch(),
    ]),
  ])
}

pub fn view_players(players: List(String), handler: fn(Option(String)) -> msg) {
  html.div([], [
    html.div(
      [],
      list.append(
        list.index_map(players, fn(item, index) {
          click_cell(
            Some(item),
            handler,
            Some("[ #" <> int.to_string(index) <> " ]"),
            Some(item),
            Name,
          )
        }),
        [
          click_cell(
            None,
            handler,
            Some("[ # NEW ]"),
            Some("Enter new player"),
            Name,
          ),
        ],
      ),
    ),
  ])
}

pub fn input_new_player(handler: fn(String) -> msg) {
  html.div([attribute.class("participant-box")], [
    input_cell("Enter player name:", handler),
  ])
}

pub fn input_cell(
  text: String,
  on_submit handle_keydown: fn(String) -> msg,
) -> Element(msg) {
  html.div([attribute.class("singles-grid")], [
    html.div([], [html.text(text)]),
    keyed.div([], [
      #("inputheader", html.text("$>")),
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
