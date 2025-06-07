import fortfound_core/card.{
  type Card, type ClubsCard, type CoinsCard, type CupsCard, type MajorArcanaCard,
  type MinorArcanaCard, type SwordsCard,
}
import gleam/function
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub opaque type MajorArcanaFoundation {
  MajorArcanaFoundation(
    low: Option(MajorArcanaCard),
    high: Option(MajorArcanaCard),
  )
}

pub const initial_major_arcana_foundation = MajorArcanaFoundation(
  low: None,
  high: None,
)

pub fn major_arcana_foundation_low_cards(
  foundation: MajorArcanaFoundation,
) -> List(MajorArcanaCard) {
  foundation.low
  |> option.map(card.major_arcanas_before)
  |> option.unwrap([])
}

pub fn major_arcana_foundation_high_cards(
  foundation: MajorArcanaFoundation,
) -> List(MajorArcanaCard) {
  foundation.high
  |> option.map(card.major_arcanas_after)
  |> option.unwrap([])
}

fn next_low_major_arcana(
  foundation: MajorArcanaFoundation,
) -> Result(MajorArcanaCard, Nil) {
  case foundation.low {
    Some(low) -> card.major_arcana_successor(low)
    None -> Ok(card.first_major_arcana)
  }
}

fn next_high_major_arcana(
  foundation: MajorArcanaFoundation,
) -> Result(MajorArcanaCard, Nil) {
  case foundation.high {
    Some(high) -> card.major_arcana_predecessor(high)
    None -> Ok(card.last_major_arcana)
  }
}

pub fn next_major_arcanas_for_foundation(
  foundation: MajorArcanaFoundation,
) -> List(MajorArcanaCard) {
  [next_low_major_arcana(foundation), next_high_major_arcana(foundation)]
  |> list.filter_map(function.identity)
}

pub fn move_major_arcana_to_foundation(
  foundation: MajorArcanaFoundation,
  card: MajorArcanaCard,
) -> MajorArcanaFoundation {
  let next_low = next_low_major_arcana(foundation)
  let next_high = next_high_major_arcana(foundation)

  case card, next_low, next_high {
    _, Ok(next_low), _ if card == next_low ->
      MajorArcanaFoundation(..foundation, low: Some(card))
    _, _, Ok(next_high) if card == next_high ->
      MajorArcanaFoundation(..foundation, high: Some(card))
    _, _, _ ->
      panic as {
        "Cannot move "
        <> string.inspect(card)
        <> " to foundation when "
        <> string.inspect(next_low)
        <> " or "
        <> string.inspect(next_high)
        <> " are expected"
      }
  }
}

pub fn major_arcana_foundation_is_complete(
  foundation: MajorArcanaFoundation,
) -> Bool {
  case next_low_major_arcana(foundation), next_high_major_arcana(foundation) {
    Error(Nil), Error(Nil) -> True
    _, _ -> False
  }
}

pub opaque type MinorArcanaFoundation {
  UnblockedMinorArcanaFoundation(cards: MinorArcanaFoundationFaces)
  BlockedMinorArcanaFoundation(
    blocked_by: Card,
    cards: MinorArcanaFoundationFaces,
  )
}

pub opaque type MinorArcanaFoundationFaces {
  MinorArcanaFoundationFaces(
    clubs: ClubsCard,
    coins: CoinsCard,
    cups: CupsCard,
    swords: SwordsCard,
  )
}

pub const initial_minor_arcana_foundation = UnblockedMinorArcanaFoundation(
  MinorArcanaFoundationFaces(
    clubs: card.first_clubs_card,
    coins: card.first_coins_card,
    cups: card.first_cups_card,
    swords: card.first_swords_card,
  ),
)

pub fn pop_blocker(
  foundation: MinorArcanaFoundation,
) -> Result(#(Card, MinorArcanaFoundation), Nil) {
  case foundation {
    BlockedMinorArcanaFoundation(blocked_by:, cards:) ->
      Ok(#(blocked_by, UnblockedMinorArcanaFoundation(cards:)))
    UnblockedMinorArcanaFoundation(..) -> Error(Nil)
  }
}

pub fn push_blocker(
  foundation: MinorArcanaFoundation,
  card: Card,
) -> Result(MinorArcanaFoundation, Nil) {
  case foundation {
    BlockedMinorArcanaFoundation(..) -> Error(Nil)
    UnblockedMinorArcanaFoundation(cards:) ->
      Ok(BlockedMinorArcanaFoundation(cards:, blocked_by: card))
  }
}

pub fn minor_arcana_foundation_cards(
  foundation: MinorArcanaFoundation,
) -> List(MinorArcanaCard) {
  case foundation {
    UnblockedMinorArcanaFoundation(cards:)
    | BlockedMinorArcanaFoundation(cards:, ..) -> [
      card.Clubs(cards.clubs),
      card.Coins(cards.coins),
      card.Cups(cards.cups),
      card.Swords(cards.swords),
    ]
  }
}

pub fn next_minor_arcanas_for_foundation(
  foundation: MinorArcanaFoundation,
) -> List(MinorArcanaCard) {
  case foundation {
    UnblockedMinorArcanaFoundation(cards:) ->
      [
        card.Clubs(cards.clubs),
        card.Coins(cards.coins),
        card.Cups(cards.cups),
        card.Swords(cards.swords),
      ]
      |> list.filter_map(card.minor_arcana_successor)
    BlockedMinorArcanaFoundation(..) -> []
  }
}

pub fn minor_arcana_foundation_faces(
  foundation: MinorArcanaFoundation,
) -> Result(MinorArcanaFoundationFaces, Nil) {
  case foundation {
    UnblockedMinorArcanaFoundation(cards:) -> Ok(cards)
    BlockedMinorArcanaFoundation(..) -> Error(Nil)
  }
}

pub fn move_minor_arcana_to_foundation(
  foundation_cards: MinorArcanaFoundationFaces,
  card: MinorArcanaCard,
) -> MinorArcanaFoundation {
  case card {
    card.Clubs(card) ->
      MinorArcanaFoundationFaces(..foundation_cards, clubs: card)
    card.Coins(card) ->
      MinorArcanaFoundationFaces(..foundation_cards, coins: card)
    card.Cups(card) ->
      MinorArcanaFoundationFaces(..foundation_cards, cups: card)
    card.Swords(card) ->
      MinorArcanaFoundationFaces(..foundation_cards, swords: card)
  }
  |> UnblockedMinorArcanaFoundation
}

pub fn minor_arcana_foundation_is_complete(
  foundation: MinorArcanaFoundation,
) -> Bool {
  foundation
  |> next_minor_arcanas_for_foundation()
  |> list.is_empty()
}
