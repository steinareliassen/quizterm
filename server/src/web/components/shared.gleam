import gleam/dynamic/decode
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import lustre/server_component

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

pub fn key_down(
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
