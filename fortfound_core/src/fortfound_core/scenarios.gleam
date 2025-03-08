import fortfound_core/game
import fortfound_core/model.{
  type State, Clubs, Coins, Cups, MajorArcana, MajorArcanaFoundation,
  MinorArcana, MinorArcanaFoundation, State, Swords,
}
import gleam/dict
import gleam/io
import gleam/option.{None, Some}

fn generate() -> model.Game {
  let game = game.init()
  case game.is_winnable(game.current_state) |> io.debug {
    True -> game
    False -> generate()
  }
}

pub fn main() {
  generate() |> io.debug
}

pub fn winnable_example() -> State {
  State(
    major_arcana_foundation: MajorArcanaFoundation(low: None, high: None),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 1,
      swords: 1,
      clubs: 1,
      cups: 1,
      blocking: None,
    ),
    columns: dict.from_list([
      #(0, [
        MinorArcana(Clubs, 9),
        MinorArcana(Swords, 11),
        MinorArcana(Swords, 4),
        MinorArcana(Clubs, 6),
        MajorArcana(13),
        MajorArcana(19),
        MinorArcana(Swords, 13),
      ]),
      #(1, [
        MajorArcana(18),
        MinorArcana(Coins, 11),
        MinorArcana(Coins, 2),
        MinorArcana(Coins, 8),
        MajorArcana(11),
        MajorArcana(10),
        MajorArcana(20),
      ]),
      #(2, [
        MajorArcana(17),
        MajorArcana(2),
        MinorArcana(Clubs, 2),
        MinorArcana(Cups, 5),
        MajorArcana(21),
        MinorArcana(Coins, 12),
        MajorArcana(3),
      ]),
      #(3, [
        MinorArcana(Swords, 9),
        MinorArcana(Cups, 12),
        MinorArcana(Clubs, 8),
        MinorArcana(Swords, 6),
        MajorArcana(5),
        MinorArcana(Coins, 5),
        MinorArcana(Cups, 2),
      ]),
      #(4, [
        MinorArcana(Clubs, 11),
        MinorArcana(Swords, 7),
        MajorArcana(9),
        MinorArcana(Swords, 8),
        MajorArcana(8),
        MinorArcana(Swords, 3),
        MinorArcana(Clubs, 7),
      ]),
      #(5, []),
      #(6, [
        MinorArcana(Cups, 4),
        MinorArcana(Coins, 7),
        MinorArcana(Swords, 12),
        MinorArcana(Swords, 10),
        MajorArcana(6),
        MajorArcana(0),
        MajorArcana(15),
      ]),
      #(7, [
        MinorArcana(Cups, 9),
        MinorArcana(Cups, 10),
        MinorArcana(Coins, 10),
        MajorArcana(4),
        MinorArcana(Clubs, 13),
        MinorArcana(Swords, 5),
        MinorArcana(Clubs, 12),
      ]),
      #(8, [
        MinorArcana(Coins, 13),
        MinorArcana(Cups, 11),
        MinorArcana(Cups, 6),
        MajorArcana(16),
        MajorArcana(7),
        MinorArcana(Clubs, 10),
        MinorArcana(Coins, 6),
      ]),
      #(9, [
        MinorArcana(Cups, 13),
        MinorArcana(Clubs, 3),
        MinorArcana(Cups, 8),
        MinorArcana(Cups, 3),
        MinorArcana(Clubs, 5),
        MajorArcana(12),
        MajorArcana(14),
      ]),
      #(10, [
        MajorArcana(1),
        MinorArcana(Cups, 7),
        MinorArcana(Clubs, 4),
        MinorArcana(Swords, 2),
        MinorArcana(Coins, 9),
        MinorArcana(Coins, 3),
        MinorArcana(Coins, 4),
      ]),
    ]),
  )
}

pub fn won_example() -> State {
  State(
    major_arcana_foundation: MajorArcanaFoundation(
      low: Some(10),
      high: Some(11),
    ),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 13,
      swords: 13,
      clubs: 13,
      cups: 13,
      blocking: None,
    ),
    columns: dict.from_list([
      #(0, []),
      #(1, []),
      #(2, []),
      #(3, []),
      #(4, []),
      #(5, []),
      #(6, []),
      #(7, []),
      #(8, []),
      #(9, []),
      #(10, []),
    ]),
  )
}

pub fn trivially_winnable_example() -> State {
  State(
    major_arcana_foundation: MajorArcanaFoundation(low: Some(8), high: Some(13)),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 13,
      swords: 13,
      clubs: 13,
      cups: 13,
      blocking: None,
    ),
    columns: dict.from_list([
      #(0, [MajorArcana(10), MajorArcana(9)]),
      #(1, [MajorArcana(11), MajorArcana(12)]),
      #(2, []),
      #(3, []),
      #(4, []),
      #(5, []),
      #(6, []),
      #(7, []),
      #(8, []),
      #(9, []),
      #(10, []),
    ]),
  )
}
