import gleam/option.{type Option, None, Some}
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html.{text}
import lustre/event

pub fn terminal_header(element: Element(a)) -> Element(a) {
  html.div([class("terminal-header")], [
    html.div([class("terminal-status")], [
      html.span([class("status-blink")], [html.text("●")]),
      html.text(" SYSTEM READY"),
      html.span([class("ml-8")], [element]),
    ]),
  ])
}

pub fn input_cell(
  header: String,
  password: Bool,
  on_input: fn(String) -> msg,
  style: Style,
) -> Element(msg) {
  [
    html.p([], [html.text("► " <> header)]),
    html.div([], [
      html.input([
        attribute.type_(case password {
          True -> "password"
          False -> "text"
        }),
        event.on_input(on_input),
        attribute.autofocus(True),
      ]),
    ]),
  ] |> div_styled(style)
}

pub fn click_cell(
  id: id,
  on_click: fn(id) -> msg,
  tag: Option(String),
  value: Option(String),
  value_style: Style,
  // todo: wrap with value option.
) -> Element(msg) {
  [
    tag |> maybe_tag(Name),
    value |> maybe_text(value_style),
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
    Login -> "participant-login"
    Box -> "participant-box"
    Name -> "participant-name"
    Answer -> "participant-answer"
    Disconnect -> "participant-disconnect"
  })
}
