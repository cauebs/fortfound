import fortfound_app/animations.{
  type Vector3, card_draw_animations, full_move_animations,
}
import fortfound_app/layout.{type Layout}
import fortfound_app/palette
import fortfound_app/special_characters.{suit_icon}
import fortfound_core/card.{type Card}
import fortfound_core/foundation
import fortfound_core/game.{type Game, empty_game, game_from_seed}
import fortfound_core/rng.{type Seed}
import fortfound_core/scenarios
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import glector.{type Vector2, Vector2}
import lustre
import lustre/animation.{type Animations}
import lustre/attribute.{type Attribute, attribute as attr}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event
import modem

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type SelectedCard {
  Dragging(
    card: Card,
    from: Location,
    position: Vector2,
    pointer_offset: Vector2,
  )
  Selected(card: Card, at: Location)
}

type Model {
  Model(
    game: Game,
    selected: Option(SelectedCard),
    layout: Layout,
    animations: Animations(Card, Vector3),
    displaying_help: Bool,
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let game =
    modem.initial_uri()
    |> result.then(parse_seed)
    |> result.map(game_from_seed)
    |> result.lazy_unwrap(empty_game)

  #(
    Model(
      game:,
      selected: None,
      layout: layout.get_layout(),
      animations: animation.new(),
      displaying_help: False,
    ),
    effect.none(),
  )
}

fn parse_seed(uri: Uri) -> Result(Seed, Nil) {
  use query <- result.try(
    uri.query
    |> option.to_result(Nil)
    |> result.then(uri.parse_query),
  )

  query
  |> dict.from_list
  |> dict.get("seed")
  |> result.then(rng.decode_seed)
}

type Scenario {
  Random
  Daily
  Specific(Seed)
}

fn scenario_to_seed(scenario: Scenario) -> Seed {
  case scenario {
    Random -> scenarios.random_winnable_scenario()
    Daily -> scenarios.current_daily_scenario()
    Specific(seed) -> seed
  }
}

type Msg {
  RequestedNewGame(Scenario)
  PressedRestart
  PressedHelp
  GrabbedCard(source: Location, position: Vector2, pointer_offset: Vector2)
  MovedPointer(Vector2)
  ReleasedCard(target: Option(Location))
  Clicked(Option(Location))
  UndoMove
  AnimationTick(Float)
}

type InputMode {
  InputBlocked
  InputAllowed
}

fn get_input_mode(animations: Animations(id, a)) -> InputMode {
  case animation.ids(animations) {
    [] -> InputAllowed
    _ -> InputBlocked
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let input_mode = get_input_mode(model.animations)

  let #(model, effect) = case input_mode, msg {
    _, RequestedNewGame(scenario) -> {
      let seed = scenario_to_seed(scenario)
      model
      |> start_game(game_from_seed(seed))
      |> with_effect(set_seed_in_uri(seed))
    }

    _, PressedRestart -> {
      case model.game.seed {
        None -> model
        Some(seed) -> {
          model |> start_game(game_from_seed(seed))
        }
      }
      |> with_no_effect()
    }

    _, UndoMove -> {
      case model.game.history {
        [HistoryStep(state_before:, ..), ..history] -> {
          let game = Game(..model.game, state: state_before, history:)
          Model(..model, game:)
          |> cancel_animations()
        }
        [] -> model
      }
      |> with_no_effect()
    }

    _, PressedHelp ->
      Model(..model, displaying_help: !model.displaying_help)
      |> with_no_effect()

    _, AnimationTick(t) ->
      Model(..model, animations: animation.tick(model.animations, t))
      |> with_no_effect()

    InputAllowed, GrabbedCard(source:, position:, pointer_offset:) -> {
      let grabbed_card = get_card(model.game.state, source)
      case model.selected, grabbed_card {
        None, Ok(card) -> {
          let dragging =
            Dragging(card:, from: source, position:, pointer_offset:)
          Model(..model, selected: Some(dragging))
        }
        _, _ -> model
      }
      |> with_no_effect()
    }

    InputAllowed, MovedPointer(position) -> {
      case model.selected {
        Some(Dragging(..) as dragging) -> {
          let position = glector.add(position, dragging.pointer_offset)
          let dragging = Dragging(..dragging, position:)
          Model(..model, selected: Some(dragging))
        }
        _ -> model
      }
      |> with_no_effect()
    }

    InputAllowed, ReleasedCard(target: None) -> {
      case model.selected {
        Some(Dragging(..)) -> model |> clear_selection()
        _ -> model
      }
      |> with_no_effect()
    }

    InputAllowed, ReleasedCard(target: Some(target)) -> {
      case model.selected {
        Some(Dragging(from: source, ..)) -> make_move(model, source, target)
        _ -> model
      }
      |> with_no_effect()
    }

    InputAllowed, Clicked(Some(target)) -> {
      case model.selected {
        Some(Selected(at: source, ..)) -> make_move(model, source, target)

        _ -> {
          case get_card(model.game.state, target) {
            Ok(card) -> {
              let selected = Selected(card:, at: target)
              Model(..model, selected: Some(selected))
            }
            Error(Nil) -> model
          }
        }
      }
      |> with_no_effect()
    }

    InputAllowed, Clicked(None) ->
      model |> clear_selection() |> with_no_effect()

    InputBlocked, _ -> model |> with_no_effect()
  }

  let animation_tick_effect = animation.effect(model.animations, AnimationTick)
  #(model, effect.batch([effect, animation_tick_effect]))
}

fn with_effect(model: Model, effect: Effect(Msg)) -> #(Model, Effect(Msg)) {
  #(model, effect)
}

fn with_no_effect(model: Model) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}

fn cancel_animations(model: Model) -> Model {
  Model(..model, animations: animation.new())
}

fn start_game(model: Model, new_game: Game) -> Model {
  Model(
    ..model,
    game: new_game,
    selected: None,
    animations: animation.new()
      |> animation.schedule_many(card_draw_animations(
        new_game.state.columns,
        model.layout,
      )),
  )
}

fn set_seed_in_uri(seed: Seed) -> Effect(Msg) {
  let query = "seed=" <> rng.encode_seed(seed)
  modem.push("", Some(query), None)
}

fn clear_selection(model: Model) -> Model {
  Model(..model, selected: None)
}

fn make_move(
  model: Model,
  source: game.Location,
  target: game.Location,
) -> Model {
  case game.make_move(model.game, MoveRequest(source, target)) {
    Ok(#(move, game_after_move)) -> {
      let animations =
        model.animations
        |> animation.schedule_many(full_move_animations(
          game_after_move,
          model.layout,
          move,
        ))
      Model(..model, game: game_after_move, selected: None, animations:)
    }

    Error(Nil) -> Model(..model, selected: None)
  }
}

fn view(model: Model) -> Element(Msg) {
  let State(
    major_arcana_foundation: major,
    columns:,
    minor_arcana_foundation: minor,
  ) = model.game.state

  case model.displaying_help {
    True -> view_help()
    False ->
      [
        case model.selected {
          Some(Dragging(card:, position:, ..)) ->
            view_dragged_card(card, position, model.layout)
          _ -> element.none()
        },
        view_animated_cards(model.animations, model.layout),
        view_major_arcana_foundation(major, model.layout, model.animations),
        view_buttons(model.layout),
        case model.game.history {
          [HistoryStep(moved:, ..), ..] -> view_undo_button(moved, model.layout)
          _ -> element.none()
        },
        view_minor_arcana_foundation(
          minor,
          model.layout,
          model.selected,
          model.animations,
        ),
        view_columns(columns, model.layout, model.selected, model.animations),
      ]
      |> list.reverse
      |> svg(2000, 1000)
  }
}

fn bullet_list(items: List(String)) -> Element(Msg) {
  items
  |> list.map(fn(item) { html.li([], [html.text(item)]) })
  |> html.ul([], _)
}

fn link(text: String, href: String) -> Element(Msg) {
  html.a([attribute.href(href), attribute.style("color", palette.button_text)], [
    html.text(text),
  ])
}

fn view_help() -> Element(Msg) {
  html.div(
    [
      attribute.styles([
        #("margin", "5vh"),
        #("font-family", "Arima"),
        #("font-size", "1.75em"),
        #("color", palette.button_text),
      ]),
    ],
    [
      html.p([], [
        html.h2([], [
          html.text("This is a clone of "),
          link(
            "Zachtronics' Fortune's Foundation",
            "https://www.zachtronics.com/solitaire-collection/",
          ),
          html.text("."),
        ]),
      ]),
      html.p([], [
        bullet_list(["Your goal is to get all cards to their foundations."]),
      ]),
      html.p([], [
        bullet_list([
          "White cards are called Minor Arcanas and black cards are called Major Arcanas.",
          "Minor Arcanas' foundations go up by suit, from Ace to King.",
          "Major Arcanas' foundation goes simultaneously up from 0 and down from 21.",
        ]),
      ]),
      html.p([], [
        bullet_list([
          "Cards of the same kind (Major Arcanas or Minor Arcanas of the same suit) can be stacked in either ascending or descending order.",
          "You can only move one card at a time, but stacked cards will follow consecutively for your convenience.",
          "You can place one single card on top of the Minor Arcanas' foundations, blocking them temporarily.",
        ]),
      ]),
      html.p([], [
        html.text("This was made with "),
        link("Gleam", "https://gleam.run"),
        html.text(" and "),
        link("Lustre", "https://lustre.build"),
        html.text("."),
        html.br([]),
        html.text("Source code is available at "),
        link(
          "github.com/cauebs/fortfound",
          "https://github.com/cauebs/fortfound",
        ),
        html.text("."),
      ]),
      html.button(
        [
          attribute.styles([
            #("background", palette.button_fill),
            #("border", "3.5px solid " <> palette.button_stroke),
            #("border-radius", "5px"),
            #("padding", "1em"),
            #("color", palette.button_text),
            #("font-family", "Arima"),
            #("font-size", "1em"),
          ]),
          event.on_click(PressedHelp),
        ],
        [html.text("Return")],
      ),
    ],
  )
}

@external(javascript, "./fortfound_app_ffi.mjs", "screen_to_svg_percentage")
fn screen_to_svg_percentage(vector: Vector2) -> Vector2

@external(javascript, "./fortfound_app_ffi.mjs", "percentage_to_absolute")
fn percentage_to_absolute(vector: Vector2) -> Vector2

fn percentage_attribute(name: String, value: Float) -> Attribute(a) {
  attr(name, float.to_string(value *. 100.0) <> "%")
}

type MouseEvent {
  MouseDown
  MouseMove
  MouseUp
  MouseClick
}

fn on_mouse_event(ev: MouseEvent, msg: fn(Vector2) -> Msg) -> Attribute(Msg) {
  let event_name = case ev {
    MouseDown -> "mousedown"
    MouseMove -> "mousemove"
    MouseUp -> "mouseup"
    MouseClick -> "click"
  }

  event.on(event_name, {
    use x <- decode.field("clientX", decode.float)
    use y <- decode.field("clientY", decode.float)
    Vector2(x, y) |> screen_to_svg_percentage() |> msg |> decode.success()
  })
}

fn svg(elements: List(Element(Msg)), width: Int, height: Int) -> Element(Msg) {
  html.svg(
    [
      attr(
        "viewBox",
        [0, 0, width, height]
          |> list.map(int.to_string)
          |> string.join(" "),
      ),
      attribute.styles([
        #("width", "100%"),
        #("max-height", "100vh"),
        #("font-family", "Arima"),
        #("font-weight", "700"),
        #("font-size", "1.75em"),
        #("user-select", "none"),
      ]),
      on_mouse_event(MouseMove, MovedPointer),
      on_mouse_event(MouseUp, fn(_) { ReleasedCard(None) }),
    ],
    elements,
  )
}

fn view_card(
  card card: Card,
  position position: Vector2,
  scale scale: Float,
  layout layout: Layout,
  loc loc: Option(game.Location),
) -> Element(Msg) {
  let size = layout.card_size |> glector.scale(scale)

  let #(text_x, text_anchor, text_dx) = case card {
    MajorArcana(_) -> #(position.x +. size.x /. 2.0, "middle", 0.0)
    MinorArcana(..) -> #(position.x, "start", layout.card_padding)
  }

  let fill_color = palette.card_fill(card)
  let main_color = palette.card_stroke(card)

  let rect =
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", fill_color),
      attr("stroke", main_color),
      attr("stroke-width", "3.5"),
    ])

  let text =
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", position.y),
        percentage_attribute("dx", text_dx),
        percentage_attribute("dy", layout.card_padding),
        attr("text-anchor", text_anchor),
        attr("dominant-baseline", "hanging"),
        attr("fill", main_color),
      ],
      card_text(card),
    )

  svg.g(
    case loc {
      Some(loc) -> [
        on_mouse_event(MouseDown, fn(mouse_pos) {
          GrabbedCard(
            source: loc,
            position:,
            pointer_offset: glector.subtract(position, mouse_pos),
          )
        }),
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(Some(loc)) }),
      ]
      _ -> []
    },
    [rect, text],
  )
}

fn view_dragged_card(
  card: Card,
  position: Vector2,
  layout: Layout,
) -> Element(Msg) {
  svg.g([attribute.style("pointer-events", "none")], [
    view_card(card, position, 1.0, layout, None),
  ])
}

fn view_slot(
  position: Vector2,
  layout: Layout,
  target: Option(game.Location),
) -> Element(Msg) {
  svg.rect(
    [
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", layout.card_size.x),
      percentage_attribute("height", layout.card_size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", palette.slot_fill),
      attr("stroke", palette.slot_stroke),
      attr("stroke-width", "3.5"),
    ]
    |> list.append(case target {
      Some(loc) -> [
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(Some(loc)) }),
      ]
      None -> []
    }),
  )
}

fn view_button(
  text: String,
  position: Vector2,
  size: Vector2,
  msg: Msg,
) -> Element(Msg) {
  let text_x = position.x +. size.x /. 2.0
  let text_y = position.y +. size.y /. 2.0

  svg.g([attr("cursor", "pointer"), on_mouse_event(MouseDown, fn(_) { msg })], [
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", palette.button_fill),
      attr("stroke", palette.button_stroke),
      attr("stroke-width", "3.5"),
    ]),
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", text_y),
        attr("text-anchor", "middle"),
        attr("dominant-baseline", "middle"),
        attr("fill", palette.button_text),
      ],
      text,
    ),
  ])
}

fn view_buttons(layout: Layout) -> Element(Msg) {
  let buttons = {
    let specs =
      [
        #("New game", RequestedNewGame(Random)),
        #("Restart", PressedRestart),
        #("Daily", RequestedNewGame(Daily)),
        #("Help", PressedHelp),
      ]
      |> list.zip(layout.button_positions(layout))

    use #(#(text, msg), position) <- list.map(specs)
    view_button(text, position, layout.button_size, msg)
  }

  svg.g([], buttons)
}

fn view_undo_button(card: Card, layout: Layout) -> Element(Msg) {
  let card_scale = 0.7
  let button_size = layout.button_size |> glector.scale(0.8)

  let center =
    Vector2(layout.column_x(5, layout), layout.foundations_y)
    |> layout.origin_to_center(layout.card_size)

  let card_position =
    layout.center_to_origin(center, glector.scale(layout.card_size, card_scale))
  let button_position = layout.center_to_origin(center, button_size)

  svg.g([], [
    view_card(card, card_position, scale: card_scale, layout:, loc: None),
    view_button("Undo", button_position, button_size, UndoMove),
  ])
}

fn view_major_arcana_foundation(
  foundation: foundation.MajorArcanaFoundation,
  layout: Layout,
  animations: Animations(Card, a),
) -> Element(Msg) {
  let column_xs = layout.major_arcana_foundation_xs(layout)

  let assert Ok(low_slot_x) = list.first(column_xs)
  let assert Ok(high_slot_x) = list.last(column_xs)
  let slots =
    [low_slot_x, high_slot_x]
    |> list.map(fn(x) {
      view_slot(Vector2(x, layout.foundations_y), layout, None)
    })

  let view_cards = fn(cards: List(#(Card, Float))) -> List(Element(Msg)) {
    cards
    |> list.filter_map(fn(card_and_x) {
      let #(card, x) = card_and_x
      case animations |> is_animating(card) {
        True -> Error(Nil)
        False -> {
          let position = Vector2(x, layout.foundations_y)
          Ok(view_card(card:, position:, scale: 1.0, layout:, loc: None))
        }
      }
    })
  }

  let lows = case foundation.low {
    Some(low) -> {
      list.range(0, low)
      |> list.map(MajorArcana)
      |> list.zip(column_xs)
      |> view_cards
    }
    None -> {
      []
    }
  }

  let highs = case foundation.high {
    Some(high) -> {
      list.range(21, high)
      |> list.map(MajorArcana)
      |> list.zip(list.reverse(column_xs))
      |> view_cards
    }
    None -> {
      []
    }
  }

  slots
  |> list.append(lows)
  |> list.append(highs)
  |> svg.g([], _)
}

fn view_minor_arcana_foundation(
  foundation: foundation.MinorArcanaFoundation,
  layout: Layout,
  selected: Option(SelectedCard),
  animations: Animations(Card, a),
) -> Element(Msg) {
  let column_xs = layout.minor_arcana_foundation_xs(layout)

  let cards = foundation.minor_arcana_foundation_faces(foundation)

  let blocker_card_or_invisible_collider = case foundation.blocker, selected {
    Some(blocker), Some(Dragging(card: dragging, ..)) if blocker == dragging ->
      element.none()

    Some(blocker), _ ->
      case animations |> is_animating(blocker) {
        True -> element.none()
        False -> view_blocker(blocker, layout)
      }

    None, _ -> {
      let assert Ok(x) = list.first(column_xs)
      let y = layout.foundations_y
      let assert Ok(width) =
        list.last(column_xs)
        |> result.map(float.add(_, layout.card_size.x /. 2.0))
      let height = layout.card_size.y

      let loc = Some(BlockingMinorArcanaFoundation)
      svg.rect([
        percentage_attribute("x", x),
        percentage_attribute("y", y),
        percentage_attribute("width", width),
        percentage_attribute("height", height),
        attr("fill", palette.transparent),
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: loc) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(loc) }),
      ])
    }
  }

  cards
  |> list.zip(column_xs)
  |> list.map(fn(card_and_x) {
    let #(card, x) = card_and_x
    let position = Vector2(x, layout.foundations_y)
    view_card(card:, position:, scale: 1.0, layout:, loc: None)
  })
  |> list.prepend(blocker_card_or_invisible_collider)
  |> list.reverse()
  |> svg.g([], _)
}

fn view_blocker(card: Card, layout: Layout) -> Element(Msg) {
  let foundation_center = layout.minor_arcana_foundation_center(layout)
  let position = layout.center_to_origin(foundation_center, layout.card_size)

  svg.g([rotate(foundation_center, 90.0)], [
    view_card(
      card:,
      position:,
      scale: 1.0,
      layout:,
      loc: Some(BlockingMinorArcanaFoundation),
    ),
  ])
}

fn rotate(position: Vector2, degrees: Float) -> Attribute(Msg) {
  let position = percentage_to_absolute(position)
  let rotation_values =
    [degrees, position.x, position.y]
    |> list.map(float.to_string)
    |> string.join(", ")

  attr("transform", "rotate(" <> rotation_values <> ")")
}

fn view_columns(
  columns: Dict(Int, List(Card)),
  layout: Layout,
  selected: Option(SelectedCard),
  animations: Animations(Card, a),
) -> Element(Msg) {
  columns
  |> dict.to_list
  |> list.map(view_column(_, layout, selected, animations))
  |> svg.g([], _)
}

fn view_column(
  column: #(Int, List(Card)),
  layout: Layout,
  selected: Option(SelectedCard),
  animations: Animations(Card, a),
) -> Element(Msg) {
  let #(column_index, cards) = column

  let x = layout.column_x(column_index, layout)
  let loc = Some(Column(column_index))

  let slot = view_slot(Vector2(x, layout.tableau_origin.y), layout, loc)

  let cards =
    cards
    |> list.reverse
    |> list.index_map(fn(card, row) {
      let y = layout.tableau_card_y(row, layout)
      let position = case selected {
        Some(Dragging(card: dragging, ..)) if card == dragging -> Error(Nil)
        Some(Selected(card: selected, ..)) if card == selected -> {
          let offset = Vector2(0.0, layout.stacked_card_y_offset)
          Ok(Vector2(x, y) |> glector.add(offset))
        }
        _ ->
          case animations |> is_animating(card) {
            True -> Error(Nil)
            False -> Ok(Vector2(x, y))
          }
      }
      let interactable = row == list.length(cards) - 1
      #(card, position, interactable)
    })
    |> list.filter_map(fn(spec) {
      let #(card, position, interactable) = spec
      use position <- result.map(position)
      let loc = case interactable {
        False -> None
        True -> loc
      }
      view_card(card:, position:, scale: 1.0, layout:, loc:)
    })

  svg.g([], [slot, ..cards])
}

fn is_animating(animations: Animations(Card, a), card: Card) -> Bool {
  animation.ids(animations) |> list.contains(card)
}

fn view_animated_cards(
  animations: Animations(Card, Vector3),
  layout: Layout,
) -> Element(Msg) {
  animations
  |> animation.values()
  |> dict.to_list()
  |> list.map(fn(card_and_position) {
    let #(card, position) = card_and_position
    #(
      position.z,
      view_card(card:, position: position.xy, scale: 1.0, layout:, loc: None),
    )
  })
  |> list.sort(fn(a, b) { int.compare(pair.first(a), pair.first(b)) })
  |> list.map(pair.second)
  |> svg.g([], _)
}
