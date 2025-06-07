import birdie
import fortfound_core/card
import fortfound_core/tableau.{
  all_column_indices, card_positions, count_stacked_cards,
  empty_and_non_empty_columns, empty_tableau, filled_tableau, pop_from_column,
  push_to_column, tableau_to_string, total_cards,
}
import gleam/dict
import gleam/int
import gleam/list
import gleam/order
import gleam/string
import startest/expect

pub fn empty_tableau_test() {
  empty_tableau()
  |> tableau_to_string()
  |> birdie.snap("empty tableau")
}

pub fn filled_tableau_test() {
  let tableau =
    card.all_playable_cards()
    |> filled_tableau()

  let positions_string =
    card.all_playable_cards()
    |> filled_tableau()
    |> card_positions()
    |> dict.to_list()
    |> list.sort(fn(a, b) {
      let #(_, position_a) = a
      let #(_, position_b) = b
      int.compare(position_a.column_index, position_b.column_index)
      |> order.break_tie(int.compare(position_a.row_index, position_b.row_index))
    })
    |> list.map(fn(card_and_position) {
      let #(card, position) = card_and_position
      string.inspect(position) <> " " <> card.card_to_string(card)
    })
    |> string.join("\n")

  { tableau_to_string(tableau) <> "\n" <> positions_string }
  |> birdie.snap("filled tableau")
}

pub fn total_cards_test() {
  card.all_playable_cards()
  |> filled_tableau()
  |> total_cards()
  |> expect.to_equal(70)
}

pub fn empty_and_non_empty_columns_test() {
  card.all_playable_cards()
  |> filled_tableau()
  |> empty_and_non_empty_columns()
  |> string.inspect()
  |> birdie.snap("empty and non-empty columns in filled tableau")
}

pub fn pop_push_test() {
  let tableau =
    card.all_playable_cards()
    |> filled_tableau()

  let assert #([empty], [non_empty, ..]) = empty_and_non_empty_columns(tableau)

  tableau
  |> pop_from_column(empty)
  |> expect.to_be_error()

  tableau
  |> pop_from_column(non_empty)
  |> expect.to_be_ok()

  let assert Ok(#(card, tableau)) =
    tableau
    |> pop_from_column(non_empty)

  tableau
  |> push_to_column(empty, card)
  |> tableau_to_string()
  |> birdie.snap("pop from first non-empty column and push to empty")
}
