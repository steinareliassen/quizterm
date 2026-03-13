import gleam/dynamic/decode
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

pub fn view_named_input(
  name: String,
  on_submit handle_keydown: fn(String, String) -> msg,
) -> Element(msg) {
  prompt_input(
    "nameinput",
    key_down(fn(a: String) { decode.success(handle_keydown(name, a)) }, fn() {
      decode.failure(handle_keydown(name, ""), "")
    }),
  )
}

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

pub fn view_yes_no(
  accepted: String,
  on_submit handle_button: fn(Option(String)) -> msg,
) -> Element(msg) {
  html.div([], [
    html.button([event.on_click(handle_button(Some(accepted)))], [
      html.text(" <Yes> "),
    ]),
    html.text(" - "),
    html.button([event.on_click(handle_button(None))], [html.text(" <No> ")]),
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
