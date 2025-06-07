import gleam/int
import gleam/list
import gleam/string

pub type Card {
  MajorArcana(MajorArcanaCard)
  MinorArcana(MinorArcanaCard)
}

pub fn card_to_string(card: Card) -> String {
  case card {
    MajorArcana(card) -> major_arcana_card_to_string(card)
    MinorArcana(card) -> minor_arcana_card_to_string(card)
  }
}

pub opaque type MajorArcanaCard {
  MajorArcanaCard(value: Int)
}

pub fn major_arcana_card_to_string(card: MajorArcanaCard) -> String {
  card.value
  |> int.to_string()
  |> string.pad_start(to: 3, with: " ")
}

const major_arcana_min_value = 0

const major_arcana_max_value = 21

pub const first_major_arcana = MajorArcanaCard(major_arcana_min_value)

pub fn major_arcana_successor(
  card: MajorArcanaCard,
) -> Result(MajorArcanaCard, Nil) {
  case card.value >= major_arcana_max_value {
    True -> Error(Nil)
    False -> Ok(MajorArcanaCard(value: card.value + 1))
  }
}

pub fn major_arcanas_before(card: MajorArcanaCard) -> List(MajorArcanaCard) {
  list.range(major_arcana_min_value, card.value)
  |> list.map(MajorArcanaCard)
}

pub fn major_arcanas_after(card: MajorArcanaCard) -> List(MajorArcanaCard) {
  list.range(card.value, major_arcana_max_value)
  |> list.map(MajorArcanaCard)
}

pub fn major_arcana_predecessor(
  card: MajorArcanaCard,
) -> Result(MajorArcanaCard, Nil) {
  case card.value <= major_arcana_min_value {
    True -> Error(Nil)
    False -> Ok(MajorArcanaCard(value: card.value - 1))
  }
}

pub const last_major_arcana = MajorArcanaCard(major_arcana_max_value)

pub type MinorArcanaCard {
  Clubs(ClubsCard)
  Coins(CoinsCard)
  Cups(CupsCard)
  Swords(SwordsCard)
}

pub fn minor_arcana_card_to_string(card: MinorArcanaCard) -> String {
  case card {
    Clubs(ClubsCard(value:))
    | Coins(CoinsCard(value:))
    | Cups(CupsCard(value:))
    | Swords(SwordsCard(value:)) ->
      suit_icon(card)
      <> case value {
        1 -> "A"
        11 -> "J"
        12 -> "Q"
        13 -> "K"
        _ ->
          value
          |> int.to_string()
      }
      |> string.pad_start(to: 2, with: " ")
  }
}

pub opaque type ClubsCard {
  ClubsCard(value: Int)
}

pub opaque type CoinsCard {
  CoinsCard(value: Int)
}

pub opaque type CupsCard {
  CupsCard(value: Int)
}

pub opaque type SwordsCard {
  SwordsCard(value: Int)
}

const minor_arcana_min_value = 1

const minor_arcana_max_value = 13

pub const first_clubs_card = ClubsCard(minor_arcana_min_value)

pub const first_coins_card = CoinsCard(minor_arcana_min_value)

pub const first_cups_card = CupsCard(minor_arcana_min_value)

pub const first_swords_card = SwordsCard(minor_arcana_min_value)

pub fn minor_arcana_successor(
  card: MinorArcanaCard,
) -> Result(MinorArcanaCard, Nil) {
  let #(constructor, value) = case card {
    Clubs(ClubsCard(value:)) -> #(fn(v) { Clubs(ClubsCard(v)) }, value)
    Coins(CoinsCard(value:)) -> #(fn(v) { Coins(CoinsCard(v)) }, value)
    Cups(CupsCard(value:)) -> #(fn(v) { Cups(CupsCard(v)) }, value)
    Swords(SwordsCard(value:)) -> #(fn(v) { Swords(SwordsCard(v)) }, value)
  }

  case value >= minor_arcana_max_value {
    True -> Error(Nil)
    False -> Ok(constructor(value + 1))
  }
}

fn are_consecutive(n1: Int, n2: Int) -> Bool {
  int.absolute_value(n1 - n2) == 1
}

pub fn are_stackable(card1: Card, card2: Card) -> Bool {
  case card1, card2 {
    MajorArcana(MajorArcanaCard(value: v1)),
      MajorArcana(MajorArcanaCard(value: v2))
    -> are_consecutive(v1, v2)

    MinorArcana(card1), MinorArcana(card2) -> {
      case card1, card2 {
        Clubs(ClubsCard(v1)), Clubs(ClubsCard(v2))
        | Coins(CoinsCard(v1)), Coins(CoinsCard(v2))
        | Cups(CupsCard(v1)), Cups(CupsCard(v2))
        | Swords(SwordsCard(v1)), Swords(SwordsCard(v2))
        -> are_consecutive(v1, v2)
        _, _ -> False
      }
    }
    _, _ -> False
  }
}

fn playable_major_arcanas() -> List(MajorArcanaCard) {
  list.range(major_arcana_min_value, major_arcana_max_value)
  |> list.map(MajorArcanaCard)
}

fn playable_minor_arcanas() -> List(MinorArcanaCard) {
  use make_card <- list.flat_map([
    fn(v) { Coins(CoinsCard(v)) },
    fn(v) { Swords(SwordsCard(v)) },
    fn(v) { Clubs(ClubsCard(v)) },
    fn(v) { Cups(CupsCard(v)) },
  ])

  list.range(minor_arcana_min_value + 1, minor_arcana_max_value)
  |> list.map(make_card)
}

pub fn all_playable_cards() -> List(Card) {
  let major_arcanas = playable_major_arcanas() |> list.map(MajorArcana)
  let minor_arcanas = playable_minor_arcanas() |> list.map(MinorArcana)
  list.append(major_arcanas, minor_arcanas)
}

// This function stays at the end of the file to avoid an LSP bug:
// https://github.com/gleam-lang/gleam/issues/3628
fn suit_icon(card: MinorArcanaCard) -> String {
  case card {
    Clubs(_) -> "♣"
    Coins(_) -> "♦"
    Cups(_) -> "♥"
    Swords(_) -> "♠"
  }
}
