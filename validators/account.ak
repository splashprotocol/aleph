use cardano/address.{Credential, Script}
use cardano/script_context.{ScriptContext, Spending}
use cardano/transaction.{Transaction}

pub const intent_proxy_hash = "intent"

validator account {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, .. } = sc
    when info is {
      Spending { .. } ->
        check_for_proxy(tx.withdrawals, Script(intent_proxy_hash))
      _ -> fail
    }
  }
}

fn check_for_proxy(
  withdrawals: Pairs<Credential, Int>,
  proxy_cred: Credential,
) -> Bool {
  expect [Pair(k, _), ..rest] = withdrawals
  or {
    proxy_cred == k,
    check_for_proxy(rest, proxy_cred),
  }
}
