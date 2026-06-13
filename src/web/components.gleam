import lustre/component
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html.{text}
import lustre/element/keyed
import lustre/event
import lustre/server_component

pub fn terminal_header(
  text: Option(String),
  element: Element(a),
) -> Element(a) {
  html.div([class("terminal-header")], [
    html.div([class("terminal-status")], [
      html.span([class("status-blink")], [html.text("●")]),
      html.text(case text {
        Some(text) -> " " <> text
        None -> " SYSTEM READY"
      }),
      html.div([class("ml-8")], [element]),
    ]),
  ])
}

pub fn input_cell(
  text: String,
  on_submit handle_keydown: fn(String) -> msg,
) -> Element(msg) {
  [
    html.div([], [html.text(text)]),
    html.div([], [
      html.text("► "),
      html.input([
        attribute.type_("text"),
        key_down(fn(a: String) { decode.success(handle_keydown(a)) }, fn() {
          decode.failure(handle_keydown(""), "")
        }),
        attribute.autofocus(True),
      ]),
    ]),
  ]
  |> div_styled(Name)
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

pub fn input_cell_2(
  pin: String,
  on_input: fn(String) -> msg,
  style: Style,
) -> Element(msg) {
  [
    html.text("► "),
    html.input([
      attribute.type_("tel"),
      attribute.value(string.repeat("*", times: string.length(pin))),
      event.on_input(on_input),
      attribute.autofocus(True),
    ]),
  ]
  |> div_styled(style)
}

pub fn click_cell(
  id: id,
  on_click: fn(id) -> msg,
  tag: Option(String),
  value: Option(String),
  value_style: Style,
) -> Element(msg) {
  [
    html.a([attribute.href("javascript:")], [
      tag |> maybe_tag(Name),
      value |> maybe_text(value_style),
    ]),
  ]
  |> div_styled_click(Login, id, on_click)
}

pub fn content_cell(
  tag: String,
  value: Option(String),
  style: Style,
) -> Element(a) {
  [tag |> text |> arr |> div_styled(Name), value |> maybe_text(Answer)]
  |> div_styled(style)
}

fn maybe_tag(value: Option(String), style: Style) -> Element(a) {
  case value {
    Some(value) -> { "► " <> value } |> text |> arr |> div_styled(style)
    None -> element.none()
  }
}

fn maybe_text(value: Option(String), style: Style) -> Element(a) {
  case value {
    Some(value) -> value |> text |> arr |> div_styled(style)
    None -> element.none()
  }
}

pub fn div_styled(elements: List(Element(a)), style: Style) {
  html.div([style_class(style)], elements)
}

fn div_styled_click(
  elements: List(Element(a)),
  style: Style,
  arg: arg,
  click: fn(arg) -> a,
) -> Element(a) {
  html.div([style_class(style), event.on_click(click(arg))], elements)
}

fn arr(value: Element(a)) {
  [value]
}

pub type Style {
  Login
  Box
  Name
  Answer
  Disconnect
}

fn style_class(style: Style) {
  class(case style {
    Login -> "box-dashed"
    Box -> "box-solid"
    Name -> "text-visible"
    Answer -> "text-part"
    Disconnect -> "box-dashed"
  })
}
