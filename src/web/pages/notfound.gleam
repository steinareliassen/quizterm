import lustre/attribute.{class}
import lustre/element
import lustre/element/html.{body, div, head, html, link, meta, script, title}
import wisp.{type Response}

pub fn html_404() -> Response {
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
║           4       0       4           ║
╚═════════════════════════════════ohno!═╝
",
              ),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
  |> element.to_document_string
  |> wisp.html_response(400)
}
