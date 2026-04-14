import gleam/option.{type Option, None, Some}
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn click_cell(
  tag: Option(String),
  id: Option(String),
  value: String,
  on_click: fn(Option(String)) -> msg,
) -> Element(msg) {
  html.div([class("participant-login"), event.on_click(on_click(id))], [
    html.div([class("participant-name")], [
      html.text(
        "► "
        <> case tag {
          Some(text) -> "[#" <> text <> "] "
          None -> ""
        }
        <> value,
      ),
    ]),
  ])
}

pub fn click_cell_pair(
  tag: Option(String),
  pair: Option(#(String, String)),
  display_value: Bool,
  on_click: fn(Option(#(String, String))) -> msg,
) -> Element(msg) {
  let value = case pair {
    Some(pair) -> {
      let #(_, value) = pair
      value
    }
    None -> ""
  }
  html.div([class("participant-login"), event.on_click(on_click(pair))], [
    html.div([class("participant-name")], [
      html.div([], [
        html.text(
          "► "
          <> case tag {
            Some(text) -> "[#" <> text <> "] "
            None -> ""
          },
        ),
      ]),
      case display_value {
        True -> html.text(value)
        False -> element.none()
      },
    ]),
  ])
}
