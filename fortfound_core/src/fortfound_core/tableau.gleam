import fortfound_core/card.{type Card}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub opaque type ColumnIndex {
  ColumnIndex(Int)
}

pub fn all_column_indices() -> List(ColumnIndex) {
  list.range(0, 10) |> list.map(ColumnIndex)
}

type Column {
  Column(cards: List(Card))
}

const empty_column = Column([])

fn filled_column(cards: List(Card)) -> Column {
  Column(cards)
}

fn push_card(column: Column, card: Card) -> Column {
  let Column(cards) = column
  Column([card, ..cards])
}

fn pop_card(column: Column) -> Result(#(Card, Column), Nil) {
  case column {
    Column([]) -> Error(Nil)
    Column([card, ..rest]) -> Ok(#(card, Column(rest)))
  }
}

fn column_size(column: Column) -> Int {
  let Column(cards) = column
  list.length(cards)
}

fn count_stacked_cards_in_column(column: Column) -> Int {
  let Column(cards) = column
  cards
  |> list.window_by_2
  |> list.count(fn(cards) { card.are_stackable(cards.0, cards.1) })
}

pub opaque type Tableau {
  Tableau(columns: Dict(ColumnIndex, Column))
}

pub fn empty_tableau() -> Tableau {
  let columns =
    all_column_indices()
    |> list.map(fn(index) { #(index, empty_column) })
    |> dict.from_list
  Tableau(columns:)
}

pub fn filled_tableau(cards: List(Card)) -> Tableau {
  let #(left, right) =
    cards
    |> list.sized_chunk(7)
    |> list.map(filled_column)
    |> list.split(5)

  let middle = [empty_column]

  let columns =
    [left, middle, right]
    |> list.flatten()
    |> list.index_map(fn(column, i) { #(ColumnIndex(i), column) })
    |> dict.from_list

  Tableau(columns:)
}

pub fn tableau_to_string(tableau: Tableau) -> String {
  all_column_indices()
  |> list.map(fn(column_index) {
    let column = get_column(tableau, column_index)
    column.cards
    |> list.reverse()
    |> list.map(fn(card) { #(column_index, card) })
  })
  |> list.transpose()
  |> list.map(fn(row) {
    let row = row |> dict.from_list()

    all_column_indices()
    |> list.map(fn(index) {
      dict.get(row, index)
      |> result.map(card.card_to_string)
      |> result.unwrap(or: string.repeat(" ", 3))
    })
    |> string.join(" | ")
  })
  |> string.join("\n")
}

fn get_column(tableau: Tableau, index: ColumnIndex) -> Column {
  let assert Ok(column) = dict.get(tableau.columns, index)
  column
}

fn set_column(tableau: Tableau, index: ColumnIndex, column: Column) -> Tableau {
  Tableau(columns: dict.insert(tableau.columns, index, column))
}

pub fn pop_from_column(
  tableau: Tableau,
  index: ColumnIndex,
) -> Result(#(Card, Tableau), Nil) {
  let result = tableau |> get_column(index) |> pop_card()
  use #(card, column) <- result.map(result)
  #(card, tableau |> set_column(index, column))
}

pub fn push_to_column(
  tableau: Tableau,
  index: ColumnIndex,
  card: Card,
) -> Tableau {
  let column = tableau |> get_column(index) |> push_card(card)
  tableau |> set_column(index, column)
}

pub fn empty_and_non_empty_columns(
  tableau: Tableau,
) -> #(List(ColumnIndex), List(ColumnIndex)) {
  all_column_indices()
  |> list.partition(fn(index) {
    tableau
    |> get_column(index)
    |> column_size()
    == 0
  })
}

pub fn total_cards(tableau: Tableau) -> Int {
  tableau.columns
  |> dict.values()
  |> list.map(column_size)
  |> int.sum()
}

pub fn count_stacked_cards(tableau: Tableau) -> Int {
  tableau.columns
  |> dict.values()
  |> list.map(count_stacked_cards_in_column)
  |> int.sum()
}

pub type Position {
  Position(column_index: Int, row_index: Int)
}

pub fn card_positions(tableau: Tableau) -> Dict(Card, Position) {
  tableau.columns
  |> dict.to_list()
  |> list.flat_map(fn(index_column) {
    let #(ColumnIndex(column_index), Column(cards)) = index_column
    use card, row_index <- list.index_map(list.reverse(cards))
    #(card, Position(column_index:, row_index:))
  })
  |> dict.from_list()
}
