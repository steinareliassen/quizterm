import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string
import group_registry.{type GroupRegistry}
import lustre
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import shared/message.{
  type NotifyClient, type NotifyServer, type RoomControl, type StateControl,
  RoomInfo,
}
import web/components.{
  Answer, Box, Name, click_cell, content_cell, div_styled, terminal_header,
}
import web/components/live/card
import web/components/live/model
import web/components/shared.{input_cell}
import web/components/single/answerlist

pub fn component() -> lustre.App(
  #(Subject(RoomControl), Subject(StateControl)),
  Game,
  GameMsg,
) {
  lustre.application(init, update, view)
}

pub type Game {
  SelectRoom(RoomModel)
  SelectPlayer(PlayerModel)
  SingleGame(answerlist.Model)
  LiveGame(model.Model)
}

pub opaque type RoomModel {
  RoomModel(
    state: RoomState,
    rooms: List(Room),
    room_handler: Subject(RoomControl),
    state_handler: Subject(StateControl),
  )
}

pub opaque type GameMsg {
  SelectRoomMsg(RoomMsg)
  PreGameMsg(Msg)
  SingleGameMsg(answerlist.Msg)
  LiveGameMsg(model.Msg)
}

type Msg {
  FetchModel(PlayerModel)
  PickedPlayer(Option(String))
  ReceiveName(name: String)
  AcceptPlayer(name: Option(String))
  PickedGame(String)
}

fn init(
  handlers: #(Subject(RoomControl), Subject(StateControl)),
) -> #(Game, Effect(GameMsg)) {
  let #(room_handler, state_handler) = handlers

  #(
    SelectRoom(RoomModel(Init, [], room_handler:, state_handler:)),
    effect.from(fn(dispatch) {
      dispatch(
        SelectRoomMsg(
          ReceiveRooms(
            list.map(
              actor.call(room_handler, 1000, message.FetchRooms),
              fn(id_room) {
                let #(id, RoomInfo(name, pin_enc)) = id_room
                Room(id:, name:, pin_enc:)
              },
            ),
          ),
        ),
      )
    }),
  )
}

pub type Room {
  Room(id: String, name: String, pin_enc: String)
}

fn update(model: Game, msg: GameMsg) {
  echo "New Message!"
  case model, msg {
    LiveGame(model), LiveGameMsg(msg) -> {
      echo "Live!"
      #(LiveGame(card.update(model, msg)), effect.none())
    }
    SingleGame(model), SingleGameMsg(msg) -> #(
      SingleGame(answerlist.update(model, msg)),
      effect.none(),
    )
    SelectPlayer(model), PreGameMsg(msg) -> update_pregame(model, msg)
    SelectRoom(_), PreGameMsg(FetchModel(model)) ->
      update_pregame(model, FetchModel(model))
    SelectRoom(model), SelectRoomMsg(msg) -> update_pickroom(model, msg)
    _, _ -> {
      echo "DISCARD!"
      #(model, effect.none())
    }
  }
}

fn update_pickroom(model: RoomModel, msg: RoomMsg) -> #(Game, Effect(GameMsg)) {
  case msg {
    Initialize -> #(
      SelectRoom(RoomModel(
        Init,
        [],
        room_handler: model.room_handler,
        state_handler: model.state_handler,
      )),
      effect.none(),
    )
    ReceiveRooms(rooms) -> #(
      SelectRoom(RoomModel(..model, rooms:, state: PickRoom)),
      effect.none(),
    )
    SelectedRoom(room) -> #(
      SelectRoom(RoomModel(..model, state: EnterPin(room:, pin: ""))),
      effect.none(),
    )
    KeyPin(pin, starkey) -> {
      let key = string.replace(in: starkey, each: "*", with: "")
      let pin = pin <> key
      case model.state {
        EnterPin(room, _) -> {
          case string.length(pin) >= 4 {
            True -> {
              echo "fetching!"
              #(
                SelectRoom(RoomModel(..model, state: EnterPin(room:, pin:))),
                fetch_players(
                  model.room_handler,
                  model.state_handler,
                  room.id,
                  pin,
                ),
              )
            }
            False -> {
              echo "pin " <> pin
              #(
                SelectRoom(RoomModel(..model, state: EnterPin(room:, pin:))),
                effect.none(),
              )
            }
          }
        }
        _ -> #(
          SelectRoom(RoomModel(
            Init,
            [],
            room_handler: model.room_handler,
            state_handler: model.state_handler,
          )),
          effect.none(),
        )
      }
    }
  }
}

fn fetch_players(
  room_handler: Subject(RoomControl),
  state_handler: Subject(StateControl),
  room: String,
  pin: String,
) {
  effect.from(fn(dispatch) {
    let assert Some(clientsserver) =
      actor.call(room_handler, 1000, message.FetchRoom(room, pin, _))
    let #(registry, player_handler) = clientsserver
    let players = actor.call(player_handler, 1000, message.FetchPlayers)
    echo "done"
    dispatch(
      PreGameMsg(
        FetchModel(PlayerModel(
          PickPlayer,
          players,
          None,
          registry,
          player_handler,
          state_handler,
          room,
          pin,
        )),
      ),
    )
  })
}

pub opaque type PlayerModel {
  PlayerModel(
    state: State,
    players: List(String),
    player: Option(String),
    registry: GroupRegistry(NotifyClient),
    player_handler: Subject(NotifyServer),
    state_handler: Subject(StateControl),
    team_id: String,
    team_pin: String,
  )
}

type State {
  PickPlayer
  PickGametype
  EnterPlayer
  AskOkPlayer(name: String)
  ListAnswers
}

fn update_pregame(model: PlayerModel, msg: Msg) {
  case msg {
    FetchModel(model) -> {
      echo "Pregame"
      #(SelectPlayer(model), effect.none())
    }
    PickedPlayer(player) -> #(
      SelectPlayer(case player {
        Some(player) -> PlayerModel(..model, state: AskOkPlayer(player))
        None -> PlayerModel(..model, state: EnterPlayer)
      }),
      effect.none(),
    )
    ReceiveName(name) -> #(
      SelectPlayer(PlayerModel(..model, state: AskOkPlayer(name))),
      effect.none(),
    )
    AcceptPlayer(Some(player)) -> {
      actor.send(model.player_handler, message.AddPlayer(player))
      #(
        SelectPlayer(
          PlayerModel(..model, player: Some(player), state: PickGametype),
        ),
        effect.none(),
      )
    }
    AcceptPlayer(None) -> #(
      SelectPlayer(PlayerModel(..model, state: PickPlayer)),
      effect.none(),
    )
    PickedGame(game_style) ->
      case model.player {
        Some(name) ->
          case game_style {
            "Live Game" -> #(
              LiveGame(model.init(
                name,
                #(model.registry, model.player_handler),
                model.team_id,
                model.team_pin,
              )),
              effect.map(
                model.subscribe(model.registry, model.get_subscription_hander()),
                fn(a) { LiveGameMsg(a) },
              ),
            )
            "Single Game" -> {
              let answer_list =
                actor.call(model.state_handler, 1000, message.FetchQuestions)
              #(
                SingleGame(answerlist.init(
                  name,
                  answer_list,
                  model.player_handler,
                )),
                effect.none(),
              )
            }
            _ -> #(
              SelectPlayer(PlayerModel(..model, state: ListAnswers)),
              effect.none(),
            )
          }
        None -> #(
          SelectPlayer(PlayerModel(..model, state: EnterPlayer)),
          effect.none(),
        )
      }
  }
}

type RoomState {
  Init
  PickRoom
  EnterPin(room: Room, pin: String)
  JoinGame(room_id: String, pin: String)
}

pub type RoomMsg {
  Initialize
  ReceiveRooms(List(Room))
  SelectedRoom(Room)
  KeyPin(String, String)
}

fn view(model: Game) -> Element(GameMsg) {
  case model {
    LiveGame(model) ->
      element.map(card.view(model), fn(msg) { LiveGameMsg(msg) })
    SingleGame(model) ->
      element.map(answerlist.view(model), fn(msg) { SingleGameMsg(msg) })
    SelectPlayer(model) ->
      element.map(view_selectplayer(model), fn(msg) { PreGameMsg(msg) })
    SelectRoom(model) ->
      element.map(view_selectroom(model), fn(msg) { SelectRoomMsg(msg) })
  }
}

fn view_selectroom(model: RoomModel) -> Element(RoomMsg) {
  case model.state {
    Init -> layout("... please wait", Some("Fetching rooms"), [])
    PickRoom -> view_room_list(model.rooms)
    EnterPin(room, pin) -> {
      case string.length(pin) >= 4 {
        True -> [html.text("Waiting!")] |> div_styled(components.Box)
        False -> view_enter_pin(room, pin)
      }
    }
    JoinGame(_, _) -> element.none()
  }
}

fn layout(
  header: String,
  ohno: option.Option(String),
  body: List(Element(RoomMsg)),
) {
  html.div([], [
    terminal_header(
      None,
      element.fragment([
        html.div([], [
          case ohno {
            None -> element.none()
            Some(x) -> html.h3([], [html.text("Fail: " <> x)])
          },
        ]),
      ]),
    ),
    html.div([attribute.class("terminal-section")], [
      html.div([attribute.class("terminal-label mb-4")], [
        html.text(header),
      ]),
      html.div([attribute.class("participants-grid")], body),
    ]),
  ])
}

fn view_room_list(items: List(Room)) -> Element(RoomMsg) {
  let room_compare = fn(a: Room, b: Room) { string.compare(a.name, b.name) }
  layout("Please Select room to play in", None, case items {
    [] -> [html.text("No rooms exist, nowhere to play! (ohno!)")]
    _ -> {
      list.sort(items, room_compare)
      |> list.index_map(fn(item, index) {
        click_cell(
          item,
          SelectedRoom,
          Some("[#" <> int.to_string(index) <> "] " <> item.name),
          None,
          components.Answer,
        )
      })
    }
  })
}

fn view_enter_pin(room: Room, pin: String) -> Element(RoomMsg) {
  layout("", None, [
    components.content_cell(
      "[ # " <> room.name <> " ] ",
      None,
      components.Login,
    ),
    components.input_cell_2(pin, KeyPin(pin, _), components.Login),
  ])
}

fn view_selectplayer(model: PlayerModel) -> Element(Msg) {
  element.fragment([
    Some(case model.state {
      EnterPlayer | PickPlayer if model.players == [] ->
        "STATUS: Please enter your name"
      PickPlayer -> "STATUS: Please select player"
      AskOkPlayer(_) -> "STATUS: Validate player"
      _ -> "STATUS: Pardon?"
    })
      |> terminal_header(element.none()),

    html.div([class("participants-grid")], [
      case model.state {
        EnterPlayer | PickPlayer ->
          case model.state {
            PickPlayer if model.players != [] ->
              view_players(
                list.map(model.players, fn(player) { player }),
                PickedPlayer,
              )
            _ ->
              html.div([], [
                components.content_cell(
                  "[ # TEAM NAME GOES HERE! ] ",
                  None,
                  components.Login,
                ),
                [
                  [html.text("[#ENTER PLAYER NAME]")]
                    |> components.div_styled(components.Name),
                  input_cell("", ReceiveName),
                ]
                  |> div_styled(components.Login),
              ])
          }
        AskOkPlayer(player) -> {
          [
            content_cell("Join as this player: " <> player, None, Answer),
            click_cell(Some(player), AcceptPlayer, Some("[# Yes]"), None, Name),
            click_cell(None, AcceptPlayer, Some("[# No]"), None, Name),
          ]
          |> div_styled(Box)
        }
        PickGametype -> {
          html.div([], [
            click(1, "Live Game"),
            click(2, "Single Game"),
            click(3, "View (non-live game) answers from players in room"),
          ])
        }
        ListAnswers -> list_answers(model.player_handler)
      },
    ]),
  ])
}

fn view_players(players: List(String), handler: fn(Option(String)) -> msg) {
  html.div([], [
    html.div(
      [],
      list.append(
        list.index_map(players, fn(item, index) {
          Some("[ #" <> int.to_string(index) <> " ]")
          |> click_cell(Some(item), handler, _, Some(item), Name)
        }),
        [
          Some("[ # NEW ]")
          |> click_cell(None, handler, _, Some("Enter new player"), Name),
        ],
      ),
    ),
  ])
}

fn list_answers(player_handler: Subject(NotifyServer)) {
  html.div(
    [],
    list.map(
      actor.call(player_handler, 2000, message.FetchAllAnswers),
      fn(line) {
        let #(num, num_list) = line
        html.div([], [
          html.text(int.to_string(num)),
          ..list.map(num_list, fn(num_line) {
            let #(player, answer) = num_line
            html.div([], [html.text(player <> " : " <> answer)])
          })
        ])
      },
    ),
  )
}

fn click(number: Int, text: String) -> Element(Msg) {
  Some("► " <> "[#" <> int.to_string(number) <> "] " <> text)
  |> click_cell(text, PickedGame, _, None, Box)
}
