use aiken/builtin
use aiken/collection/list
use aiken/crypto.{ScriptHash, VerificationKey, VerificationKeyHash}
use cardano/address.{Credential, Script}
use cardano/script_context.{ScriptContext, Spending}
use cardano/transaction.{Transaction}
use list_ext
use types.{Magic}

pub type AccountState {
  /// Used to recognise accounts
  magic: Data<Magic>,
  /// Set of allowed delegatees
  allowlist: Data<List<ScriptHash>>,
  /// Monotonically increasing counter used to protect account from replay attacks 
  nonce: Data<List<Int>>,
  /// Credentials used to authorize intents. main cred and an optional co-cred
  hot_cred: (Data<VerificationKey>, Data<VerificationKey>),
  /// Credential for direct spening
  cold_cred: Data<VerificationKeyHash>,
  /// Local store of the account used by dapps to save intermediate state
  store: Data<ByteArray>,
}

pub type AccountAction {
  /// Delegate control to third-party intent witness
  Delegate(Int)
  /// Direct operation carried by owner 
  Direct
}

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
            check_for_witness(
              tx.withdrawals,
              Script(list_ext.at(allowlist, delegate) |> builtin.un_b_data),
            )
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
