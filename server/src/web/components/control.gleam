// IMPORTS ---------------------------------------------------------------------
import gleam/erlang/process.{type Subject}
import gleam/otp/actor.{type Started}
import gleam/pair
import group_registry.{type GroupRegistry}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{text}
import lustre/element/keyed
import lustre/event
import lustre/server_component
import shared/message.{
  type NotifyClient, type NotifyServer, AnswerQuiz, RevealAnswer,
}

pub fn component() -> lustre.App(message.ClientsServer, Model, Msg) {
  lustre.application(init, update, view)
}

type State {
  Quiz
  Reveal
}

pub opaque type Model {
  Model(
    state: State,
    registry: GroupRegistry(NotifyClient),
    handler: Started(Subject(NotifyServer)),
  )
}

pub opaque type Msg {
  AnnounceQuiz
  AnnounceAnswer
  PurgePlayers
  SharedMessage(message: message.NotifyClient)
}

fn init(handlers: message.ClientsServer) -> #(Model, Effect(Msg)) {
  let #(registry, handler) = handlers

  let model = Model(state: Quiz, registry:, handler:)
  #(model, subscribe(pair.first(handlers), SharedMessage))
}

fn subscribe(
  registry: GroupRegistry(topic),
  on_msg handle_msg: fn(topic) -> msg,
) -> Effect(msg) {
  use _, _ <- server_component.select
  let subject = group_registry.join(registry, "quiz", process.self())

  let selector =
    process.new_selector()
    |> process.select_map(subject, handle_msg)

  selector
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let handler = model.handler
  #(
    case msg {
      PurgePlayers -> {
        // Temp removed button to issue this action.
        actor.send(handler.data, message.PurgePlayers)
        model
      }
      AnnounceQuiz -> {
        actor.send(handler.data, AnswerQuiz)
        Model(..model, state: Quiz)
      }
      AnnounceAnswer -> {
        actor.send(handler.data, RevealAnswer)
        Model(..model, state: Reveal)
      }
      SharedMessage(message.Await) -> Model(..model, state: Reveal)
      SharedMessage(_) -> model
    },
    effect.none(),
  )
}

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("terminal-section")], [
    html.div([attribute.class("participants-grid")], [
      element.fragment([
        [text("")] |> html.div([attribute.class("participand-hidden")], _),
        [text("")] |> html.div([attribute.class("participand-hidden")], _),
        [text("")] |> html.div([attribute.class("participand-hidden")], _),
        case model.state {
          Quiz -> {
            [#("reveal", view_button("Reveal answers", AnnounceAnswer))]
            |> keyed.div([attribute.class("control")], _)
          }
          Reveal -> {
            [#("next", view_button("Ask next question", AnnounceQuiz))]
            |> keyed.div([attribute.class("control")], _)
          }
        },
      ]),
    ]),
  ])
}

fn view_button(text: String, handler: msg) -> Element(msg) {
  html.button([attribute.class("controlbutton"), event.on_click(handler)], [
    html.text(text),
  ])
}
