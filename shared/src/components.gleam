import gleam/option.{type Option, None, Some}
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn click_cell(
  id: id,
  on_click: fn(id) -> msg,
  tag: Option(String),
  value: Option(String),
) -> Element(msg) {
  html.div([class("participant-login"), event.on_click(on_click(id))], [
    html.div([class("participant-name")], [
      html.div([], [
        html.text(
          "► "
          <> case tag {
            Some(tag) -> tag
            None -> ""
          },
        ),
      ]),
      case value {
        Some(value) -> html.text(value)
        None -> element.none()
      },
    ]),
  ])
}
