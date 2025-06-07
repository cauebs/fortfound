import fortfound_app/layout.{type Layout}
import fortfound_core/card.{type Card}
import fortfound_core/game.{type Game, AtColumn}
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam_community/maths.{cos, sin, tau}
import glector.{type Vector2, Vector2}
import lustre/animation.{type Animation}

pub type Vector3 {
  Vector3(xy: Vector2, z: Float)
}

pub fn card_draw_animations(
  columns: Dict(Int, List(Card)),
  layout: Layout,
) -> List(#(Card, Animation(Vector3))) {
  let start = Vector2(layout.column_x(5, layout), layout.foundations_y)

  columns
  |> dict.to_list
  |> list.sort(fn(column1, column2) { int.compare(column1.0, column2.0) })
  |> list.map(fn(column) {
    let #(column_index, cards) = column

    cards
    |> list.reverse
    |> list.index_map(fn(card, row) {
      let stop =
        Vector2(
          layout.column_x(column_index, layout),
          layout.tableau_card_y(row, layout),
        )

      #(card, stop)
    })
  })
  |> list.transpose
  |> list.flatten
  |> list.index_map(fn(card_and_stop, index) {
    let #(card, stop) = card_and_stop

    let z = int.to_float(index)
    let interpolator = fn(t) {
      let xy = glector.lerp(start, stop, t)
      Vector3(xy:, z:)
    }
    let delay = 50.0 *. z
    let duration = 200.0

    let animation =
      animation.create(with: interpolator, for: duration)
      |> animation.add_delay(delay)

    #(card, animation)
  })
}

fn stacked_card_move_animation(
  move: game.PartialMove,
  game_after_move: Game,
  index_in_stack: Int,
  moved_stack_size: Int,
  layout: Layout,
) -> #(Card, Animation(Vector3)) {
  let assert #(AtColumn(source_column), AtColumn(target_column)) = #(
    move.source,
    move.target,
  )

  let assert Ok(source_column_size) =
    game_after_move.state.columns
    |> dict.get(source_column)
    |> result.map(list.length)

  let assert Ok(target_column_size) =
    game_after_move.state.columns
    |> dict.get(target_column)
    |> result.map(list.length)

  let row_offset = moved_stack_size - index_in_stack
  let source_row = source_column_size + row_offset - 1
  let target_row = target_column_size - row_offset

  let start =
    Vector3(
      xy: Vector2(
        layout.column_x(source_column, layout),
        layout.tableau_card_y(source_row, layout),
      ),
      z: moved_stack_size - index_in_stack,
    )

  let stop =
    Vector3(
      xy: Vector2(
        layout.column_x(target_column, layout),
        layout.tableau_card_y(target_row, layout),
      ),
      z: index_in_stack,
    )

  let interpolator = stacked_card_move_interpolator(start, stop)
  let delay = 100.0 *. int.to_float(index_in_stack)
  let duration = 200.0

  let animation =
    animation.create(with: interpolator, for: duration)
    |> animation.add_delay(delay)

  #(move.card, animation)
}

fn stacked_card_move_interpolator(
  start: Vector3,
  stop: Vector3,
) -> fn(Float) -> Vector3 {
  fn(t) {
    let curvature = 0.5

    let xy =
      glector.lerp(start.xy, stop.xy, t)
      |> glector.add(Vector2(0.0, curvature *. t *. { 1.0 -. t }))

    let z =
      { stop.z - start.z }
      |> int.to_float
      |> float.multiply(t)
      |> float.round
      |> int.add(start.z)

    Vector3(xy:, z:)
  }
}

fn move_to_foundation_animation(
  move: game.MoveToFoundation,
  game_after_move: Game,
  index: Int,
  row_offset: Int,
  layout: Layout,
) -> #(Card, Animation(Vector3)) {
  let start = case move.source {
    BlockingMinorArcanaFoundation -> {
      let foundation_center = layout.minor_arcana_foundation_center(layout)
      layout.center_to_origin(foundation_center, layout.card_size)
    }
    AtColumn(i) -> {
      let assert Ok(column_size) =
        game_after_move.state.columns
        |> dict.get(i)
        |> result.map(list.length)
      Vector2(
        x: layout.column_x(i, layout),
        y: layout.tableau_card_y(column_size + row_offset, layout),
      )
    }
  }

  let assert Ok(stop_x) = case move.card {
    MajorArcana(value) -> {
      layout.major_arcana_foundation_xs(layout)
      |> list.drop(value)
      |> list.first
    }
    MinorArcana(suit:, ..) -> {
      layout.minor_arcana_foundation_xs(layout)
      |> list.drop(case suit {
        Clubs -> 0
        Coins -> 1
        Cups -> 2
        Swords -> 3
      })
      |> list.first
    }
  }
  let stop = Vector2(stop_x, layout.foundations_y)

  let interpolator = fn(t) {
    let xy = glector.lerp(start, stop, t *. t)
    Vector3(xy:, z: 0)
  }
  let delay = 200.0 *. int.to_float(index)
  let duration = 400.0

  let animation =
    animation.create(with: interpolator, for: duration)
    |> animation.add_delay(delay)

  #(move.card, animation)
}

pub fn full_move_animations(
  game_after_move: Game,
  layout: Layout,
  move: game.FullMove,
) -> List(#(Card, Animation(Vector3))) {
  [
    move.stacked
      |> list.index_map(fn(partial_move, index_in_stack) {
        stacked_card_move_animation(
          partial_move,
          game_after_move,
          index_in_stack,
          list.length(move.stacked),
          layout,
        )
      }),
    move.to_foundations
      |> list.sort(by: fn(move1, move2) {
        case move1.source, move2.source {
          BlockingMinorArcanaFoundation, BlockingMinorArcanaFoundation ->
            order.Eq
          BlockingMinorArcanaFoundation, AtColumn(_) -> order.Lt
          AtColumn(_), BlockingMinorArcanaFoundation -> order.Gt
          AtColumn(i1), AtColumn(i2) -> int.compare(i1, i2)
        }
      })
      |> list.group(by: fn(move) { move.source })
      |> dict.values
      |> list.reverse
      |> list.flat_map(fn(moves_from_same_location) {
        moves_from_same_location
        |> list.index_map(fn(move, i) {
          #(move, list.length(moves_from_same_location) - 1 + i)
        })
        |> list.reverse
      })
      |> list.index_map(fn(move_and_offset, index) {
        let #(move, row_offset) = move_and_offset
        move_to_foundation_animation(
          move,
          game_after_move,
          index,
          row_offset,
          layout,
        )
      }),
  ]
  |> list.flatten
}

pub fn win_animations() -> List(#(Card, Animation(Vector3))) {
  let offset_delay = 50.0
  use card, index <- list.index_map(card.all_cards())

  let animation =
    win_animation(card)
    |> animation.add_delay(offset_delay *. int.to_float(index))

  #(card, animation)
}

fn win_animation(card: Card) -> Animation(Vector3) {
  animation.create(with: lucy_interpolator, for: 5000.0)
  |> animation.looping()
}

fn lucy_interpolator(t: Float) -> Vector3 {
  let a = 3.0 *. tau() *. t
  let b = 2.0 *. tau() *. t

  let x = cos(a) -. 2.25 *. cos(b)
  let y = { sin(a) +. 2.25 *. sin(b) } *. 2.0

  let xy =
    Vector2(x:, y:)
    |> glector.scale(0.075)
    |> glector.add(Vector2(x: 0.5, y: 0.5))

  let z = sin(tau() *. t)
  Vector3(xy:, z:)
}
