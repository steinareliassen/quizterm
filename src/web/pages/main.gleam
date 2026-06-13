import lustre/attribute.{class}
import lustre/element
import lustre/element/html.{body, div, head, html, link, meta, script, title}
import lustre/server_component
import wisp.{type Response}

pub fn main_html() -> Response {
  html([], [
    head([], [
      meta([attribute.charset("utf-8")]),
      meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1.0"),
      ]),
      title([], "QUIZTERMINAL v1.0"),
      script(
        [attribute.type_("module"), attribute.src("/lustre/runtime.mjs")],
        "",
      ),
      link([
        attribute.rel("stylesheet"),
        attribute.type_("text/css"),
        attribute.href("/static/layout.css"),
      ]),
    ]),
    body([], [
      div([class("terminal-screen")], [
        div([class("terminal-glow")], [
          div([class("scanlines")], []),

          // title
          div([class("terminal-header")], [
            html.pre([class("terminal-title")], [
              html.text(
                "
╔═══════════════════════════════════════╗
║       Q U I Z T E R M I N A L         ║
╚═══════════════════════════════════════╝
",
              ),
            ]),
          ]),
          server_component.element([server_component.route("/socket/game")], []),
        ]),
      ]),
    ]),
  ])
  |> element.to_document_string
  |> wisp.html_response(200)
}
