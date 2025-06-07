import birdie
import fortfound_core/card.{all_playable_cards, card_to_string}
import gleam/list
import gleam/string

pub fn all_playable_cards_test() {
  all_playable_cards()
  |> list.map(card_to_string)
  |> string.join("\n")
  |> birdie.snap("all playable cards")
}
