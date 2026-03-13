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
  let on_keydown =
    event.on("keydown", {
      use key <- decode.field("key", decode.string)
      use value <- decode.subfield(["target", "value"], decode.string)

      case key {
        "Enter" if value != "" -> decode.success(handle_keydown(name, value))
        _ -> decode.failure(handle_keydown("", ""), "")
      }
    })
    |> server_component.include(["key", "target.value"])

  prompt_input("nameinput", on_keydown)
}

pub fn view_named_keyed_input(
  question: Int,
  name: String,
  on_submit handle_keydown: fn(String, Int, String) -> msg,
) -> Element(msg) {
  let on_keydown =
    event.on("keydown", {
      use key <- decode.field("key", decode.string)
      use value <- decode.subfield(["target", "value"], decode.string)

      case key {
        "Enter" if value != "" ->
          decode.success(handle_keydown(name, question, value))
        _ -> decode.failure(handle_keydown("", 0, ""), "")
      }
    })
    |> server_component.include(["key", "target.value"])

  prompt_input("keyput", on_keydown)
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

pub fn view_input(
  on_submit handle_keydown: fn(String) -> msg,
) -> Element(msg) {
  let on_keydown =
    event.on("keydown", {
      use key <- decode.field("key", decode.string)
      use value <- decode.subfield(["target", "value"], decode.string)

      case key {
        "Enter" if value != "" -> decode.success(handle_keydown(value))
        _ -> decode.failure(handle_keydown(""), "")
      }
    })
    |> server_component.include(["key", "target.value"])

  prompt_input("input", on_keydown)
}

fn prompt_input(key, on_keydown) {
  keyed.div([], [
    #(key<>"header", html.text("$>")),
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
