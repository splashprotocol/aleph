use aiken/builtin
use data.{dataify}
use types.{Nonce}

pub fn nonce_at(list: List<Data>, index: Int) -> Data {
  if index == 0 {
    builtin.head_list(list)
  } else {
    nonce_at(builtin.tail_list(list), index - 1)
  }
}

pub fn check_nonce(
  curr_nonce: List<Data<Int>>,
  next_nonce: List<Data<Int>>,
  target_index: Int,
  target_nonce: Nonce,
) -> Bool {
  when curr_nonce is {
    [] -> True
    [c, ..curr_nonce] ->
      when next_nonce is {
        [] -> False
        [n, ..next_nonce] ->
          if target_index == 0 {
            and {
              builtin.un_i_data(c) <= target_nonce,
              builtin.un_i_data(n) == target_nonce,
              curr_nonce == next_nonce,
            }
          } else {
            check_nonce(curr_nonce, next_nonce, target_index - 1, target_nonce)
          }
      }
  }
}

test check_nonce_first_ok() {
  check_nonce(
    [dataify(0), dataify(0), dataify(0), dataify(0), dataify(0)],
    [dataify(3), dataify(0), dataify(0), dataify(0), dataify(0)],
    0,
    3,
  )
}

test check_nonce_last_ok() {
  check_nonce(
    [dataify(0), dataify(0), dataify(0), dataify(0), dataify(0)],
    [dataify(0), dataify(0), dataify(0), dataify(0), dataify(3)],
    4,
    3,
  )
}
