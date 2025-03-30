use account
use cardano/address.{Address, Script}
use cardano/assets.{add, from_lovelace}
use cardano/script_context.{ScriptContext, Spending}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, placeholder,
}
use constants.{account_magic}
use intent.{dataify}
use types.{AccountState, Direct}

const null_hash =
  #"0000000000000000000000000000000000000000000000000000000000000000"

test cold_spend_success() {
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let cold_owner = "cold_owner"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: [],
      nonce: 0,
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: cold_owner,
      store: null_hash,
    }
  let account_in_ref = OutputReference("tx0", 0)
  let inputs =
    [
      Input(
        account_in_ref,
        Output(
          account_address,
          from_lovelace(1000) |> add("foo", "bar", 1),
          InlineDatum(account_state_0),
          None,
        ),
      ),
    ]

  let account_sc =
    ScriptContext(
      Transaction {
        ..placeholder,
        inputs: inputs,
        extra_signatories: [cold_owner],
      },
      Direct,
      Spending(account_in_ref, Some(intent.dataify(account_state_0))),
    )

  account.account.else(account_sc)
}
