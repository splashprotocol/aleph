use aiken/builtin

pub fn at(list: List<a>, index: Int) -> a {
  if index == 0 {
    builtin.head_list(list)
  } else {
    at(builtin.tail_list(list), index - 1)
  }
}
