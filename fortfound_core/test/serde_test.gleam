import fortfound_core/scenarios
import fortfound_core/serde
import startest/expect

pub fn roundtrip_test() {
  let state = scenarios.winnable_example()

  state
  |> serde.encode_state
  |> serde.decode_state
  |> expect.to_equal(Ok(state))
}
