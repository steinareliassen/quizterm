// IMPORTS ---------------------------------------------------------------------
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor.{type Started}
import gleam/pair
import group_registry.{type GroupRegistry}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import lustre/server_component
import shared/message.{
  type NotifyClient, type NotifyServer, AnswerQuiz, RevealAnswer,
}

pub fn component() -> lustre.App(
  #(GroupRegistry(NotifyClient), Started(Subject(NotifyServer))),
  Model,
  Msg,
) {
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
  End
  SharedMessage(message: message.NotifyClient)
}

fn init(
  handlers: #(GroupRegistry(NotifyClient), Started(Subject(NotifyServer))),
) -> #(Model, Effect(Msg)) {
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
  let registry = model.registry
  let handler = model.handler
  case msg {
    PurgePlayers -> {
      actor.send(handler.data, message.PurgePlayers)
      #(model, effect.none())
    }
    AnnounceQuiz -> {
      actor.send(handler.data, AnswerQuiz)
      #(Model(Quiz, registry:, handler:), effect.none())
    }
    AnnounceAnswer -> {
      actor.send(handler.data, RevealAnswer)
      #(Model(Reveal, registry:, handler:), effect.none())
    }
    End -> #(model, effect.none())
    SharedMessage(_) -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  case model.state {
    Quiz -> {
      element.fragment([
        keyed.div([attribute.class("control")], [
          #("reveal", view_button("Reveal answers", AnnounceAnswer)),
        ]),
      ])
    }
    Reveal -> {
      element.fragment([
        keyed.div([attribute.class("control")], [
          #("next", view_button("Ask for next answer", AnnounceQuiz)),
        ]),
      ])
    }
  }
}

fn view_button(text: String, on_submit handle_keydown: msg) -> Element(msg) {
  let on_keydown = event.on("click", { decode.success(handle_keydown) })

  html.button([attribute.class("controlbutton"), on_keydown], [
    html.text(text),
  ])
}
