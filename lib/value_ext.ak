use aiken/builtin
use aiken/collection/dict.{Dict, to_pairs}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_asset_name, ada_policy_id, add,
  lovelace_of as lovelace_of_std, quantity_of as quantity_of_std, to_dict, zero,
}

pub fn lovelace_of(val: Value) -> (Int, Pairs<ByteArray, Dict<ByteArray, Int>>) {
  expect [ada_pol, ..remainder] = val |> to_dict |> to_pairs
  let lovelace =
    ada_pol
      |> builtin.snd_pair
      |> dict.to_pairs
      |> builtin.head_list
      |> builtin.snd_pair
  (lovelace, remainder)
}

pub fn quantity_of(
  val: Pairs<ByteArray, Dict<ByteArray, Int>>,
  policy: PolicyId,
  asset: AssetName,
) -> (Int, Pairs<ByteArray, Dict<ByteArray, Int>>) {
  val |> do_quantity_of(policy, asset)
}

fn do_quantity_of(
  val: Pairs<ByteArray, Dict<ByteArray, Int>>,
  policy: PolicyId,
  asset: AssetName,
) -> (Int, Pairs<ByteArray, Dict<ByteArray, Int>>) {
  when val is {
    [] -> (0, val)
    [Pair(x, y), ..xs] ->
      if builtin.less_than_equals_bytearray(policy, x) {
        if policy == x {
          let (q, remainder) = do_asset_of(y |> to_pairs(), asset)
          if remainder == [] {
            (q, xs)
          } else {
            (q, [Pair(x, remainder |> dict.from_ascending_pairs), ..xs])
          }
        } else {
          (0, [Pair(x, y), ..xs])
        }
      } else {
        let (q, rest) = do_quantity_of(xs, policy, asset)
        (q, [Pair(x, y), ..rest])
      }
  }
}

fn do_asset_of(
  val: Pairs<ByteArray, Int>,
  asset: AssetName,
) -> (Int, Pairs<ByteArray, Int>) {
  when val is {
    [] -> (0, val)
    [Pair(x, y), ..xs] ->
      if builtin.less_than_equals_bytearray(asset, x) {
        if asset == x {
          (y, xs)
        } else {
          (0, [Pair(x, y), ..xs])
        }
      } else {
        let (q, rest) = do_asset_of(xs, asset)
        (q, [Pair(x, y), ..rest])
      }
  }
}

const fixture_match_benchmark_right: Value =
  zero
    |> add(ada_policy_id, ada_asset_name, 1337)
    |> add(
        #"0246a14d04c3a0e9b65f6b90a3d1aa5faee5d56ab1e30ec7e8b02f29",
        "MATTR",
        200,
      )
    |> add(
        #"0a9e126256cb38c4865cdac6eb2ada51c328ba0df2ebde22ae126c0d",
        "ProphecyPoster076",
        1,
      )
    |> add(
        #"1774343241680e4daef7cbfe3536fc857ce23fb66cd0b66320b2e3dd",
        "BISON",
        12_004_999_999,
      )
    |> add(
        #"279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f",
        "SNEK",
        1486,
      )
    |> add(
        #"651dfc074202423585996ffa717cb45237d307e705e2cc3dab1ccabd",
        "MAYZSilverFoundersEdition0035",
        1,
      )
    |> add(
        #"63df49056617dd14034986cf7c250bad6552fd2f0f9c71d797932008",
        "CardanoSpaceSession",
        20,
      )
    |> add(
        #"5b01968867e13432afaa2f814e1d15e332d6cd0aa77e350972b0967d",
        "ADAOGovernanceToken",
        1,
      )
    |> add(
        #"a0028f350aaabe0545fdcb56b039bfb08e4bb4d8c4d7c3c7d481c235",
        "HOSKY",
        400_001_000,
      )
    |> add(
        #"da8c30857834c6ae7203935b89278c532b3995245295456f993e1d24",
        "LQ",
        10_635_899,
      )
    |> add(
        #"95d9a98c2f7999a3d5e0f4d795cb1333837c09eb0f24835cd2ce954c",
        "GrandmasterAdventurer659",
        1,
      )
    |> add(
        #"702cbdb06a81ef2fa4f85f9e32159c03f502539d762a71194fc11eb3",
        "AdventurerOfThiolden8105",
        1,
      )
    |> add(
        #"d0112837f8f856b2ca14f69b375bc394e73d146fdadcc993bb993779",
        "DiscoSolaris3725",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld535",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld1213",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld1518",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld1537",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld4199",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld3767",
        1,
      )
    |> add(
        #"7597444754551a8c17edbf7291cdaeca898ca02ee4e732b09a949396",
        "Algae1",
        1,
      )

const fixture_match_benchmark_left: Value =
  fixture_match_benchmark_right
    |> add(
        #"7597444754551a8c17edbf7291cdaeca898ca02ee4e732b09a949396",
        "Algae2",
        1,
      )

test test_quantity_of_non_ada() {
  let (q, rem) =
    quantity_of(
      fixture_match_benchmark_left |> to_dict |> to_pairs,
      #"7597444754551a8c17edbf7291cdaeca898ca02ee4e732b09a949396",
      "Algae2",
    )
  and {
    q == 1,
    rem == ( fixture_match_benchmark_right |> to_dict |> to_pairs ),
  }
}

test test_quantity_of_ada() {
  let (q, rem) = lovelace_of(fixture_match_benchmark_left)
  and {
    q == 1337,
    rem == (
      fixture_match_benchmark_left |> to_dict |> to_pairs |> builtin.tail_list
    ),
  }
}

test bench_quantity_of_non_ada() {
  expect _ =
    quantity_of(
      fixture_match_benchmark_left |> to_dict |> to_pairs,
      #"7597444754551a8c17edbf7291cdaeca898ca02ee4e732b09a949396",
      "Algae2",
    )
}

test bench_quantity_of_non_ada_std() {
  expect _ =
    quantity_of_std(
      fixture_match_benchmark_left,
      #"7597444754551a8c17edbf7291cdaeca898ca02ee4e732b09a949396",
      "Algae2",
    )
}

test bench_quantity_of_ada() {
  expect _ = lovelace_of(fixture_match_benchmark_left)
}

test bench_quantity_of_ada_std() {
  expect _ = lovelace_of_std(fixture_match_benchmark_left)
}
