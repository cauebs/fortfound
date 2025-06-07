import gleam/float
import gleam/int
import gleam/list
import glector.{type Vector2, Vector2}

pub fn origin_to_center(origin origin: Vector2, size size: Vector2) -> Vector2 {
  glector.add(origin, glector.scale(size, 0.5))
}

pub fn center_to_origin(center center: Vector2, size size: Vector2) -> Vector2 {
  glector.subtract(center, glector.scale(size, 0.5))
}

fn card_size() -> Vector2 {
  let width = 1.0 /. 13.0
  let height = 0.24
  Vector2(x: width, y: height)
}

fn margins() -> Vector2 {
  Vector2(0.02, 0.02)
}

fn foundations_y(margins margins: Vector2) -> Float {
  margins.y
}

fn foundations_height(card_size card_size: Vector2) -> Float {
  card_size.y
}

fn button_size(
  card_size card_size: Vector2,
  margins margins: Vector2,
) -> Vector2 {
  let width = card_size.x
  let height = card_size.y /. 2.0 -. margins.y /. 2.0
  Vector2(x: width, y: height)
}

// const undo_button_card_scale: Float = 0.7

fn stacked_card_y_offset(card_size card_size: Vector2) -> Float {
  card_size.y /. 6.0
}

fn card_padding(stacked_card_y_offset stacked_card_y_offset: Float) -> Float {
  stacked_card_y_offset /. 6.0
}

fn tableau_origin(
  foundations_y foundations_y: Float,
  foundations_height foundations_height: Float,
  margins margins: Vector2,
) -> Vector2 {
  let y = foundations_y +. foundations_height +. margins.y *. 2.0
  Vector2(0.0, y)
}

fn tableau_width(margins margins: Vector2) -> Float {
  1.0 -. 2.0 *. margins.x
}

pub fn column_xs(
  margins margins: Vector2,
  tableau_width tableau_width: Float,
  card_size card_size: Vector2,
) -> List(Float) {
  let cards_total_width = card_size.x *. 11.0
  let card_margin = { tableau_width -. cards_total_width } /. 10.0
  let offset = card_margin +. card_size.x

  use column <- list.map(list.range(0, 10))
  margins.x +. offset *. int.to_float(column)
}

pub type Layout {
  Layout(
    margins: Vector2,
    card_size: Vector2,
    card_padding: Float,
    foundations_y: Float,
    foundations_height: Float,
    button_size: Vector2,
    tableau_origin: Vector2,
    tableau_width: Float,
    column_xs: List(Float),
    stacked_card_y_offset: Float,
  )
}

pub fn get_layout() -> Layout {
  let margins = margins()
  let card_size = card_size()
  let stacked_card_y_offset = stacked_card_y_offset(card_size:)
  let card_padding = card_padding(stacked_card_y_offset:)
  let foundations_y = foundations_y(margins:)
  let foundations_height = foundations_height(card_size:)
  let button_size = button_size(card_size:, margins:)
  let tableau_origin =
    tableau_origin(foundations_y:, foundations_height:, margins:)
  let tableau_width = tableau_width(margins:)
  let column_xs = column_xs(margins:, tableau_width:, card_size:)

  Layout(
    margins:,
    card_size:,
    card_padding:,
    foundations_y:,
    foundations_height:,
    button_size:,
    tableau_origin:,
    tableau_width:,
    column_xs:,
    stacked_card_y_offset:,
  )
}

pub fn column_x(column: Int, layout: Layout) -> Float {
  let assert Ok(x) =
    layout.column_xs
    |> list.drop(column)
    |> list.first()
  x
}

pub fn major_arcana_foundation_xs(layout: Layout) -> List(Float) {
  let first = column_x(0, layout)
  let last = column_x(3, layout)
  let offset = { last -. first } /. 21.0

  list.range(0, 21)
  |> list.map(int.to_float)
  |> list.map(fn(i) { first +. offset *. i })
}

pub fn major_arcana_foundation_card_position(
  value: Int,
  layout: Layout,
) -> Vector2 {
  let assert Ok(x) =
    major_arcana_foundation_xs(layout)
    |> list.drop(value)
    |> list.first()
  Vector2(x:, y: layout.foundations_y)
}

pub fn minor_arcana_foundation_xs(layout: Layout) -> List(Float) {
  list.range(7, 10) |> list.map(column_x(_, layout))
}

pub fn minor_arcana_foundation_center(layout: Layout) -> Vector2 {
  let column_xs = minor_arcana_foundation_xs(layout)

  Vector2(float.sum(column_xs) /. 4.0, layout.foundations_y)
  |> glector.add(glector.scale(layout.card_size, 0.5))
}

pub fn button_positions(layout: Layout) -> List(Vector2) {
  let left = column_x(4, layout)
  let right = column_x(6, layout)

  let top = layout.foundations_y
  let bottom = top +. layout.button_size.y +. layout.margins.y

  [
    Vector2(left, top),
    Vector2(left, bottom),
    Vector2(right, top),
    Vector2(right, bottom),
  ]
}

// pub fn undo_button_position(layout: Layout) -> Vector2 {
//   let button_size = layout.button_size |> glector.scale(0.8)

//   let center =
//     Vector2(column_x(5, layout), layout.foundations_y)
//     |> origin_to_center(layout.card_size)

//   let card_position =
//     center_to_origin(
//       center,
//       glector.scale(layout.card_size, undo_button_card_scale),
//     )
//   center_to_origin(center, button_size)
// }

pub fn tableau_card_y(row: Int, layout: Layout) -> Float {
  let offset = layout.stacked_card_y_offset
  layout.tableau_origin.y +. offset *. int.to_float(row)
}

pub fn tableau_card_position(column: Int, row: Int, layout: Layout) -> Vector2 {
  Vector2(column_x(column, layout), tableau_card_y(row, layout))
}
