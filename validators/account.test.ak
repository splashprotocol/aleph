use account
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script}
use cardano/assets.{add, from_lovelace}
use cardano/script_context.{ScriptContext, Spending}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, placeholder,
}
use constants.{account_magic}
use data.{dataify}

use types.{AccountState, Direct, Delegate}

const null_hash =
  #"0000000000000000000000000000000000000000000000000000000000000000"

fn cold_spend(cold_owner: ByteArray, signer: ByteArray) {
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: [],
      nonce: [0, 0, 0, 0, 0],
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
        extra_signatories: [signer],
      },
      Direct,
      Spending(account_in_ref, Some(dataify(account_state_0))),
    )

  account.account.else(account_sc)
}

test cold_spend_sucess() {
  cold_spend("owner", "owner")
}

test cold_spend_bad_auth() {
  !cold_spend("owner", "adversary")
}

fn delegate(allowlist: List<ScriptHash>, delegated_to: ScriptHash, real_witness: ScriptHash) {
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: allowlist,
      nonce: [0, 0, 0, 0, 0],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
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
        withdrawals: [Pair(Script(real_witness), 0)],
      },
      Delegate(delegated_to),
      Spending(account_in_ref, Some(dataify(account_state_0))),
    )

  account.account.else(account_sc)
}

test delegate_success() {
  delegate(["wit"], "wit", "wit")
}

test delegate_witness_not_allowed() {
  !delegate(["wit"], "another_wit", "another_wit")
}

test delegate_witness_mismatch() fail {
  delegate(["wit"], "wit", "bad_wit")
}
