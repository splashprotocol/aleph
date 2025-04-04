use aiken/builtin
use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/script_context.{ScriptContext, Spending}
use cardano/transaction.{Transaction}
use types.{AccountAction, AccountState, Delegate, Direct}

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
                |> builtin.unconstr_fields
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
          Direct -> {
            expect state: AccountState = datum
            list.has(tx.extra_signatories, builtin.un_b_data(state.cold_cred))
          }
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
