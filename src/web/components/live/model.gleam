import gleam/erlang/process.{type Subject}
import group_registry.{type GroupRegistry}
import lustre/effect.{type Effect}
import lustre/server_component
import shared/message.{type NotifyClient, type NotifyServer, type User, User}

pub type State {
  Init
  Wait
  Answer
}

pub type Model {
  Model(
  state: State,
  name: String,
  lobby: #(String, List(User)),
  registry: GroupRegistry(NotifyClient),
  handler: Subject(NotifyServer),
  team_id: String,
  team_pin: String,
  )
}

pub fn init(
name: String,
handlers: message.ClientsServer,
team_id: String,
team_pin: String,
) -> Model {
  let #(registry, handler) = handlers
  Model(Init, name, #("", []), registry, handler, team_id, team_pin)
}

pub fn get_subscription_hander() {
  SharedMessage
}

pub fn subscribe(
registry: GroupRegistry(NotifyClient),
on_msg handle_msg: fn(NotifyClient) -> msg,
) -> Effect(msg) {
  use _, _ <- server_component.select
  let subject = group_registry.join(registry, "quiz", process.self())

  let selector =
  process.new_selector()
  |> process.select_map(subject, handle_msg)

  selector
}

pub type Msg {
  SharedMessage(message: NotifyClient)
  GiveAnswer(answer: String)
}

