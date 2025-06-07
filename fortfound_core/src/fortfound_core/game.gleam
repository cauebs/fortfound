import fortfound_core/card.{type Card}
import fortfound_core/foundation.{
  type MajorArcanaFoundation, type MinorArcanaFoundation,
}
import fortfound_core/rng.{type Seed, random_seed, shuffle}
import fortfound_core/tableau.{type Tableau}
import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/pair
import gleam/result
import gleam/set.{type Set}

pub opaque type State {
  State(
    major_arcana_foundation: MajorArcanaFoundation,
    minor_arcana_foundation: MinorArcanaFoundation,
    tableau: Tableau,
  )
}

fn empty_state() -> State {
  State(
    major_arcana_foundation: foundation.initial_major_arcana_foundation,
    minor_arcana_foundation: foundation.initial_minor_arcana_foundation,
    tableau: tableau.empty_tableau(),
  )
}

pub opaque type Game {
  Game(seed: Option(Seed), state: State, history: List(HistoryStep))
}

pub fn empty_game() -> Game {
  Game(seed: None, state: empty_state(), history: [])
}

pub fn game_from_seed(seed: Seed) -> Game {
  let tableau =
    card.all_playable_cards()
    |> shuffle(seed)
    |> tableau.filled_tableau()
  let state = State(..empty_state(), tableau:)
  Game(..empty_game(), seed: Some(seed), state:)
}

pub fn get_seed(game: Game) -> Result(Seed, Nil) {
  game.seed |> option.to_result(Nil)
}

pub opaque type HistoryStep {
  HistoryStep(moved: Card, state_before: State)
}

pub fn undo_move(game: Game) -> Result(Game, Nil) {
  case game.history {
    [HistoryStep(state_before:, ..), ..history] ->
      Ok(Game(..game, state: state_before, history:))
    [] -> Error(Nil)
  }
}

pub opaque type MoveRequest {
  MoveRequest(source: Location, target: Location)
}

pub type PartialMove {
  PartialMove(source: Location, card: Card, target: Location)
}

pub type MoveToFoundation {
  MoveToFoundation(source: Location, card: Card)
}

pub type FullMove {
  FullMove(
    requested: PartialMove,
    stacked: List(PartialMove),
    to_foundations: List(MoveToFoundation),
  )
}

pub type Location {
  AtColumn(tableau.ColumnIndex)
  BlockingMinorArcanaFoundation
}

fn all_locations() -> List(Location) {
  let at_columns = tableau.all_column_indices() |> list.map(AtColumn)
  [BlockingMinorArcanaFoundation, ..at_columns]
}

fn next_cards_for_foundations(state: State) -> List(Card) {
  list.append(
    foundation.next_major_arcanas_for_foundation(state.major_arcana_foundation)
      |> list.map(card.MajorArcana),
    foundation.next_minor_arcanas_for_foundation(state.minor_arcana_foundation)
      |> list.map(card.MinorArcana),
  )
}

fn find_ready_for_foundation(state: State) -> List(Location) {
  let next_cards_for_foundations = next_cards_for_foundations(state)

  all_locations()
  |> list.filter(fn(loc) {
    case pop_card(state, loc) {
      Ok(#(card, _)) -> next_cards_for_foundations |> list.contains(card)
      _ -> False
    }
  })
}

fn move_card_to_foundation(state: State, card: Card) -> Result(State, Nil) {
  case card {
    card.MajorArcana(card) -> {
      let major_arcana_foundation =
        state.major_arcana_foundation
        |> foundation.move_major_arcana_to_foundation(card)
      Ok(State(..state, major_arcana_foundation:))
    }

    card.MinorArcana(card) -> {
      use minor_arcana_foundation <- result.try(
        state.minor_arcana_foundation
        |> foundation.minor_arcana_foundation_faces()
        |> result.map(foundation.move_minor_arcana_to_foundation(_, card)),
      )
      Ok(State(..state, minor_arcana_foundation:))
    }
  }
}

fn pop_card(state: State, source: Location) -> Result(#(Card, State), Nil) {
  case source {
    BlockingMinorArcanaFoundation -> {
      use #(card, minor_arcana_foundation) <- result.map(
        state.minor_arcana_foundation |> foundation.pop_blocker(),
      )
      #(card, State(..state, minor_arcana_foundation:))
    }
    AtColumn(index) -> {
      use #(card, tableau) <- result.map(
        state.tableau |> tableau.pop_from_column(index),
      )
      #(card, State(..state, tableau:))
    }
  }
}

fn push_card(state: State, card: Card, target: Location) -> Result(State, Nil) {
  case target {
    BlockingMinorArcanaFoundation -> {
      use minor_arcana_foundation <- result.map(
        state.minor_arcana_foundation |> foundation.push_blocker(card),
      )
      State(..state, minor_arcana_foundation:)
    }
    AtColumn(index) -> {
      let tableau = state.tableau |> tableau.push_to_column(index, card)
      Ok(State(..state, tableau:))
    }
  }
}

fn move_card(
  state: State,
  request: MoveRequest,
) -> Result(#(PartialMove, State), Nil) {
  use #(card, state) <- result.try(pop_card(state, request.source))
  use new_state <- result.try(push_card(state, card, request.target))
  Ok(#(PartialMove(request.source, card, request.target), new_state))
}

fn move_stack(
  state: State,
  request: MoveRequest,
) -> Result(#(PartialMove, List(PartialMove), State), Nil) {
  use #(first, state_after_first) <- result.try(move_card(state, request))

  let #(rest, new_state) = case move_stack(state_after_first, request) {
    Ok(#(second, others, new_state)) -> #([second, ..others], new_state)
    Error(_) -> #([], state_after_first)
  }

  Ok(#(first, rest, new_state))
}

fn validate_move(
  state: State,
  request: MoveRequest,
) -> Result(#(FullMove, State), Nil) {
  use <- bool.guard(request.source == request.target, return: Error(Nil))

  let move_result = move_stack(state, request)
  use #(requested, stacked, new_state) <- result.then(move_result)

  let #(to_foundations, new_state) = apply_colaterals(new_state)
  Ok(#(FullMove(requested:, stacked:, to_foundations:), new_state))
}

pub fn make_move(
  game: Game,
  source: Location,
  target: Location,
) -> Result(#(FullMove, Game), Nil) {
  let move_result = validate_move(game.state, MoveRequest(source:, target:))
  use #(move, new_state) <- result.then(move_result)
  let history = [HistoryStep(move.requested.card, game.state), ..game.history]
  let game = Game(..game, state: new_state, history:)
  Ok(#(move, game))
}

fn is_won(state: State) -> Bool {
  state.major_arcana_foundation
  |> foundation.major_arcana_foundation_is_complete()
  && state.minor_arcana_foundation
  |> foundation.minor_arcana_foundation_is_complete()
}

fn cartesian_product(l1: List(a), l2: List(a)) -> List(#(a, a)) {
  use first <- list.flat_map(l1)
  use second <- list.map(l2)
  #(first, second)
}

fn valid_moves(state: State) -> List(#(FullMove, State)) {
  let #(empty_columns, non_empty_columns) =
    tableau.empty_and_non_empty_columns(state.tableau)

  let sources = non_empty_columns |> list.map(AtColumn)
  let targets = case empty_columns {
    // This avoids listing multiple moves to different empty columns,
    // which are effectively equivalent.
    [index, ..] -> [AtColumn(index), ..sources]
    [] -> sources
  }

  // Minor arcana foundation is either a source or a target,
  // depending on whether there is a card blocking it.
  let #(sources, targets) = case
    foundation.pop_blocker(state.minor_arcana_foundation)
  {
    Ok(_) -> #([BlockingMinorArcanaFoundation, ..sources], targets)
    Error(Nil) -> #(sources, [BlockingMinorArcanaFoundation, ..targets])
  }

  cartesian_product(sources, targets)
  |> list.filter_map(fn(source_target) {
    let #(source, target) = source_target
    validate_move(state, MoveRequest(source, target))
  })
}

fn apply_colaterals(state: State) -> #(List(MoveToFoundation), State) {
  case find_ready_for_foundation(state) {
    [] -> #([], state)
    locations -> {
      let #(moves, state) = {
        use #(moves, state), location <- list.fold(locations, from: #([], state))

        let assert Ok(#(card, state)) = pop_card(state, location)
        let assert Ok(state) = state |> move_card_to_foundation(card)

        let moves = [MoveToFoundation(location, card), ..moves]
        #(moves, state)
      }

      let #(other_moves, state) = apply_colaterals(state)
      #(list.append(other_moves, moves), state)
    }
  }
}

fn score(state: State) -> Int {
  let #(empty_columns, _) = tableau.empty_and_non_empty_columns(state.tableau)

  { 100 * list.length(empty_columns) }
  - { 10 * tableau.total_cards(state.tableau) }
  + tableau.count_stacked_cards(state.tableau)
}

fn is_winnable(game: Game) -> Bool {
  is_winnable_aux([game.state], set.new())
}

fn merge_and_dedup(
  list1: List(a),
  list2: List(a),
  key: fn(a, a) -> Order,
) -> List(a) {
  case list1, list2 {
    [], _ -> list2
    _, [] -> list1
    [head1, ..tail1], [head2, ..tail2] ->
      case key(head1, head2) {
        order.Lt -> [head1, ..merge_and_dedup(tail1, list2, key)]
        order.Eq -> merge_and_dedup(tail1, list2, key)
        order.Gt -> [head2, ..merge_and_dedup(list1, tail2, key)]
      }
  }
}

fn compare_scores(s1: State, s2: State) -> Order {
  int.compare(score(s1), score(s2))
}

fn is_winnable_aux(pending: List(State), previous: Set(State)) -> Bool {
  case pending {
    [] -> False
    [state, ..rest_of_pending] ->
      case is_won(state) {
        True -> True
        False -> {
          let previous = previous |> set.insert(state)

          let next_states = valid_moves(state) |> list.map(pair.second)

          let pending =
            next_states
            |> list.filter(fn(state) { !set.contains(previous, state) })
            |> list.sort(by: compare_scores |> order.reverse)
            |> merge_and_dedup(rest_of_pending, compare_scores |> order.reverse)

          is_winnable_aux(pending, previous)
        }
      }
  }
}

fn random_game() -> Game {
  let game = game_from_seed(random_seed())
  // Do not accept initial state where some cards can immediately go to foundations.
  case find_ready_for_foundation(game.state) {
    [] -> game
    _ -> random_game()
  }
}

pub fn random_winnable_game() -> Game {
  let game = random_game()
  case is_winnable(game) {
    True -> game
    False -> random_winnable_game()
  }
}
