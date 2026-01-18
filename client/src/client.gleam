import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", [])

  Nil
}

// MODEL -----------------------------------------------------------------------
type Answer {
  Answer(question: Int, answer: String)
}

type Model {
  Model(
    user: String,
    key: String,
    items: List(Answer),
    new_item: String,
    saving: Bool,
    error: Option(String),
  )
}

fn init(items: List(Answer)) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      user: "",
      key: "",
      items: items,
      new_item: "",
      saving: False,
      error: option.None,
    )

  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  ServerCompleted(Result(Response(String), rsvp.Error))
  AddAnswer
  TypeAnswer(String)
  SaveAnswer
  UpdateAnswer(question: Int, answer: String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ServerCompleted(state) -> #(
      Model(..model, saving: False, error: case state {
        Ok(_) -> option.None
        Error(_) -> option.Some("Failed to save list")
      }),
      effect.none(),
    )

    UserAddedItem -> {
      case model.new_item {
        "" -> #(model, effect.none())
        name -> {
          let item = Answer(name, 1, name)
          let updated_items = list.append(model.items, [item])

          #(Model(..model, items: updated_items, new_item: ""), effect.none())
        }
      }
    }

    TypeAnswer(typing) -> #(Model(..model, new_item: typing), effect.none())

    SaveAnswer -> #(Model(..model, saving: True), save_list(model.items))

    UpdateAnswer(question:, answer:) -> {
      let updated_items =
        list.index_map(model.items, fn(item, item_index) {
          case item_index == question {
            True -> Answer(..item, question:)
            False -> item
          }
        })

      #(Model(..model, items: updated_items), effect.none())
    }
  }
}

fn save_answer(user: String, key: String, answer: Answer) -> Effect(Msg) {
  let body =
    shared.jsonify_answer(shared.AnswerRequest(
      user: model.user,
      key: model.key,
      question: answer.question,
      answer: answer.answer,
    ))
  let url = "/api/answer"

  rsvp.post(url, body, rsvp.expect_ok_response(ServerCompleted))
}

fn fetch_answers(items: Answer) -> Effect(Msg) {
  let body =
    shared.jsonify_answer(shared.AnswerRequest(
      user: model.user,
      key: model.key,
      question: answer.question,
      answer: answer.answer,
    ))
  let url = "/api/answers"

  rsvp.post(url, body, rsvp.expect_ok_response(ServerCompleted))
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let styles = [
    #("max-width", "30ch"),
    #("margin", "0 auto"),
    #("display", "flex"),
    #("flex-direction", "column"),
    #("gap", "1em"),
  ]

  case model.key {
    "" -> html.div([], [])
    _ ->
      html.div([attribute.styles(styles)], [
        html.h1([], [html.text("Answers")]),
        view_grocery_list(model.items),
        view_new_item(model.new_item),
        html.div([], [
          html.button(
            [event.on_click(UserSavedList), attribute.disabled(model.saving)],
            [
              html.text(case model.saving {
                True -> "Saving..."
                False -> "Save List"
              }),
            ],
          ),
        ]),
        case model.error {
          option.None -> element.none()
          option.Some(error) ->
            html.div([attribute.style("color", "red")], [html.text(error)])
        },
      ])
  }
}

fn view_new_item(new_item: String) -> Element(Msg) {
  html.div([], [
    html.input([
      attribute.placeholder("Enter item name"),
      attribute.value(new_item),
      event.on_input(UserTypedNewItem),
    ]),
    html.button([event.on_click(UserAddedItem)], [html.text("Add")]),
  ])
}

fn view_grocery_list(items: List(Answer)) -> Element(Msg) {
  case items {
    [] -> html.p([], [html.text("No items in your list yet.")])
    _ -> {
      html.ul(
        [],
        list.index_map(items, fn(item, index) {
          html.li([], [view_grocery_item(item, index)])
        }),
      )
    }
  }
}

fn view_grocery_item(item: Answer, index: Int) -> Element(Msg) {
  html.div([attribute.styles([#("display", "flex"), #("gap", "1em")])], [
    html.span([attribute.style("flex", "1")], [html.text(item.name)]),
    html.input([
      attribute.style("width", "4em"),
      attribute.type_("number"),
      attribute.value(int.to_string(item.quantity)),
      attribute.min("0"),
      event.on_input(fn(value) {
        result.unwrap(int.parse(value), 0)
        |> UserUpdatedQuantity(index, quantity: _)
      }),
    ]),
  ])
}
