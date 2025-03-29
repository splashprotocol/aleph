use aiken/builtin
use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/script_context.{ScriptContext, Spending}
use cardano/transaction.{Transaction}
use types.{AccountAction, Delegate, Direct}

pub const swap_intent_proxy_hash = "intent"

validator account {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc
    when info is {
      Spending { datum: Some(datum), .. } -> {
        expect redeemer: AccountAction = redeemer
        when redeemer is {
          Delegate(delegate) -> {
            let allowlist =
              datum
                |> builtin.un_constr_data
                |> builtin.snd_pair
                |> builtin.tail_list
                |> builtin.head_list
                |> builtin.un_list_data
            and {
              list.has(allowlist, delegate),
              check_for_witness(
                tx.withdrawals,
                Script(builtin.un_b_data(delegate)),
              ),
            }
          }
          Direct -> False
        }
      }
      _ -> fail
    }
  }
}

fn check_for_witness(
  withdrawals: Pairs<Credential, Int>,
  witness_cred: Credential,
) -> Bool {
  expect [Pair(k, _), ..rest] = withdrawals
  or {
    witness_cred == k,
    check_for_witness(rest, witness_cred),
  }
}
