use account
use aiken/collection/list
use cardano/address.{Address, Script}
use cardano/assets.{ada_asset_name, ada_policy_id, add, from_lovelace}
use cardano/script_context.{ScriptContext, Spending, Withdrawing}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, placeholder,
}
use constants.{account_magic}
use data.{dataify}
use intent.{BatchRedeemer}
use types.{AccountState, AuthorizedIntention, Delegate, Intention, Sig}

const null_hash =
  #"0000000000000000000000000000000000000000000000000000000000000000"

const swap_intent_proxy_hash = "intent"

test exec_intent_atomic_success() {
  exec_intent_atomic(10, 500, 500)
}

test exec_intent_atomic_bad_rate() {
  !exec_intent_atomic(10, 500, 499)
}

test exec_intent_atomic_bad_fee() {
  !exec_intent_atomic(11, 500, 500)
}

fn exec_intent_atomic(consumed_fee: Int, consumed_input: Int, added_output: Int) {
  let operator = "operator"
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 0],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
      store: null_hash,
    }
  let account_in_ref = OutputReference("tx0", 0)
  let lovelace_initial = 1000
  let inputs =
    [
      Input(
        account_in_ref,
        Output(
          account_address,
          from_lovelace(lovelace_initial) |> add("foo", "bar", 1),
          InlineDatum(account_state_0),
          None,
        ),
      ),
    ]
  let account_state_1 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 2],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
      store: null_hash,
    }
  let outputs =
    [
      Output(
        account_address,
        from_lovelace(lovelace_initial - consumed_fee - consumed_input)
          |> add("foo", "bar", 1)
          |> add("tok", "tn", 0 + added_output),
        InlineDatum(account_state_1),
        None,
      ),
    ]

  let tx =
    Transaction {
      ..placeholder,
      inputs: inputs,
      outputs: outputs,
      extra_signatories: [operator],
      withdrawals: [Pair(Script(swap_intent_proxy_hash), 0)],
    }

  let account_sc =
    ScriptContext(
      tx,
      Delegate(swap_intent_proxy_hash),
      Spending(account_in_ref, Some(dataify(account_state_0))),
    )

  let intent_1 =
    Intention {
      target_nonce: (4, 2),
      leaving_asset: (ada_policy_id, ada_asset_name),
      leaving_amount: 500,
      arriving_asset: ("tok", "tn"),
      expected_arriving_amount: 500,
      fee_lovelace: 10,
      operator,
    }
  let auth_intent_1 =
    AuthorizedIntention {
      intent: intent_1,
      remainder: 0,
      auth: Sig {
        prefix: "",
        postfix: "",
        signature: #"6c07080dd51ddca5f5ac4a28ce412b34ffa44dc57b27141b184efd698e452a504d987c3850c43a4b3aecc8166be4cc5758ed3649679e403f4a8d1720ee0293c4",
        update_proof: [],
      },
    }
  let batch_redeemer = BatchRedeemer { intentions: [auth_intent_1] }

  let intent_sc =
    ScriptContext(
      tx,
      batch_redeemer,
      Withdrawing(Script(swap_intent_proxy_hash)),
    )

  and {
    account.account.else(account_sc),
    intent.batch_intention.else(intent_sc),
  }
}

test exec_intent_atomic_co_sign_success() {
  let operator = "operator"
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let co_owner = owner
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 0],
      hot_cred: (dataify(owner), dataify(co_owner)),
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
  let account_state_1 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 2],
      hot_cred: (dataify(owner), dataify(co_owner)),
      cold_cred: "cold_owner",
      store: null_hash,
    }
  let outputs =
    [
      Output(
        account_address,
        from_lovelace(490) |> add("foo", "bar", 1) |> add("tok", "tn", 500),
        InlineDatum(account_state_1),
        None,
      ),
    ]

  let tx =
    Transaction {
      ..placeholder,
      inputs: inputs,
      outputs: outputs,
      extra_signatories: [operator],
      withdrawals: [Pair(Script(swap_intent_proxy_hash), 0)],
    }

  let account_sc =
    ScriptContext(
      tx,
      Delegate(swap_intent_proxy_hash),
      Spending(account_in_ref, Some(dataify(account_state_0))),
    )

  let intent_1 =
    Intention {
      target_nonce: (4, 2),
      leaving_asset: (ada_policy_id, ada_asset_name),
      leaving_amount: 500,
      arriving_asset: ("tok", "tn"),
      expected_arriving_amount: 500,
      fee_lovelace: 10,
      operator,
    }
  let auth_intent_1 =
    AuthorizedIntention {
      intent: intent_1,
      remainder: 0,
      auth: Sig {
        prefix: "",
        postfix: "",
        signature: #"6c07080dd51ddca5f5ac4a28ce412b34ffa44dc57b27141b184efd698e452a504d987c3850c43a4b3aecc8166be4cc5758ed3649679e403f4a8d1720ee0293c4",
        update_proof: [],
      },
    }
  let batch_redeemer = BatchRedeemer { intentions: [auth_intent_1] }

  let intent_sc =
    ScriptContext(
      tx,
      batch_redeemer,
      Withdrawing(Script(swap_intent_proxy_hash)),
    )

  and {
    account.account.else(account_sc),
    intent.batch_intention.else(intent_sc),
  }
}

test exec_intent_continous_success() {
  let operator = "operator"
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
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
  let account_state_1 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 2],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
      store: #"ca1dceb60bc4e65660265e2929fd0e8801bd994fd35dd01442bfe157da76057a",
    }
  let outputs =
    [
      Output(
        account_address,
        from_lovelace(694) |> add("foo", "bar", 1) |> add("tok", "tn", 300),
        InlineDatum(account_state_1),
        None,
      ),
    ]

  let tx =
    Transaction {
      ..placeholder,
      inputs: inputs,
      outputs: outputs,
      extra_signatories: [operator],
      withdrawals: [Pair(Script(swap_intent_proxy_hash), 0)],
    }

  let account_sc =
    ScriptContext(
      tx,
      Delegate(swap_intent_proxy_hash),
      Spending(account_in_ref, Some(dataify(account_state_0))),
    )

  let intent_1 =
    Intention {
      target_nonce: (4, 2),
      leaving_asset: (ada_policy_id, ada_asset_name),
      leaving_amount: 500,
      arriving_asset: ("tok", "tn"),
      expected_arriving_amount: 500,
      fee_lovelace: 10,
      operator,
    }
  let auth_intent_1 =
    AuthorizedIntention {
      intent: intent_1,
      remainder: 200,
      auth: Sig {
        prefix: "",
        postfix: "",
        signature: #"6c07080dd51ddca5f5ac4a28ce412b34ffa44dc57b27141b184efd698e452a504d987c3850c43a4b3aecc8166be4cc5758ed3649679e403f4a8d1720ee0293c4",
        update_proof: [],
      },
    }
  let batch_redeemer = BatchRedeemer { intentions: [auth_intent_1] }

  let intent_sc =
    ScriptContext(
      tx,
      batch_redeemer,
      Withdrawing(Script(swap_intent_proxy_hash)),
    )

  and {
    account.account.else(account_sc),
    intent.batch_intention.else(intent_sc),
  }
}

test bench_exec_intent_atomic() {
  let batch_size = 20
  let operator = "operator"
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 0],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
      store: null_hash,
    }
  let inputs =
    list.foldl(
      list.range(0, batch_size - 1),
      [],
      fn(i, acc) {
        [
          Input(
            OutputReference("tx0", i),
            Output(
              account_address,
              from_lovelace(1000) |> add("foo", "bar", 1),
              InlineDatum(account_state_0),
              None,
            ),
          ),
          ..acc
        ]
      },
    )
  let account_state_1 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 2],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
      store: null_hash,
    }
  let output =
    Output(
      account_address,
      from_lovelace(490) |> add("foo", "bar", 1) |> add("tok", "tn", 500),
      InlineDatum(account_state_1),
      None,
    )
  let outputs = list.map(inputs, fn(_) { output })

  let tx =
    Transaction {
      ..placeholder,
      inputs: inputs,
      outputs: outputs,
      extra_signatories: [operator],
      withdrawals: [Pair(Script(swap_intent_proxy_hash), 0)],
    }

  let intent_1 =
    Intention {
      target_nonce: (4, 2),
      leaving_asset: (ada_policy_id, ada_asset_name),
      leaving_amount: 500,
      arriving_asset: ("tok", "tn"),
      expected_arriving_amount: 500,
      fee_lovelace: 10,
      operator,
    }
  let auth_intent_1 =
    AuthorizedIntention {
      intent: intent_1,
      remainder: 0,
      auth: Sig {
        prefix: "",
        postfix: "",
        signature: #"6c07080dd51ddca5f5ac4a28ce412b34ffa44dc57b27141b184efd698e452a504d987c3850c43a4b3aecc8166be4cc5758ed3649679e403f4a8d1720ee0293c4",
        update_proof: [],
      },
    }
  let batch_redeemer =
    BatchRedeemer { intentions: list.map(inputs, fn(_) { auth_intent_1 }) }

  let intent_sc =
    ScriptContext(
      tx,
      batch_redeemer,
      Withdrawing(Script(swap_intent_proxy_hash)),
    )

  and {
    list.foldl(
      inputs,
      True,
      fn(i, acc) {
        acc && account.account.else(
          ScriptContext(
            tx,
            Delegate(swap_intent_proxy_hash),
            Spending(i.output_reference, Some(dataify(account_state_0))),
          ),
        )
      },
    ),
    intent.batch_intention.else(intent_sc),
  }
}

test bench_exec_intent_continous() {
  let batch_size = 20
  let operator = "operator"
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 0],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
      store: null_hash,
    }
  let inputs =
    list.foldl(
      list.range(0, batch_size - 1),
      [],
      fn(i, acc) {
        [
          Input(
            OutputReference("tx0", i),
            Output(
              account_address,
              from_lovelace(1000)
                |> add("foo", "bar", 1)
                |> add("foo", "baz", 9)
                |> add("raz", "baz", 100),
              InlineDatum(account_state_0),
              None,
            ),
          ),
          ..acc
        ]
      },
    )
  let account_state_1 =
    AccountState {
      magic: account_magic,
      allowlist: [swap_intent_proxy_hash],
      nonce: [0, 0, 0, 0, 2],
      hot_cred: (dataify(owner), dataify([])),
      cold_cred: "cold_owner",
      store: #"ca1dceb60bc4e65660265e2929fd0e8801bd994fd35dd01442bfe157da76057a",
    }
  let output =
    Output(
      account_address,
      from_lovelace(694)
        |> add("foo", "bar", 1)
        |> add("foo", "baz", 9)
        |> add("raz", "baz", 100)
        |> add("tok", "tn", 300),
      InlineDatum(account_state_1),
      None,
    )
  let outputs = list.map(inputs, fn(_) { output })

  let tx =
    Transaction {
      ..placeholder,
      inputs: inputs,
      outputs: outputs,
      extra_signatories: [operator],
      withdrawals: [Pair(Script(swap_intent_proxy_hash), 0)],
    }

  let intent_1 =
    Intention {
      target_nonce: (4, 2),
      leaving_asset: (ada_policy_id, ada_asset_name),
      leaving_amount: 500,
      arriving_asset: ("tok", "tn"),
      expected_arriving_amount: 500,
      fee_lovelace: 10,
      operator,
    }
  let auth_intent_1 =
    AuthorizedIntention {
      intent: intent_1,
      remainder: 200,
      auth: Sig {
        prefix: "",
        postfix: "",
        signature: #"6c07080dd51ddca5f5ac4a28ce412b34ffa44dc57b27141b184efd698e452a504d987c3850c43a4b3aecc8166be4cc5758ed3649679e403f4a8d1720ee0293c4",
        update_proof: [],
      },
    }
  let batch_redeemer =
    BatchRedeemer { intentions: list.map(inputs, fn(_) { auth_intent_1 }) }

  let intent_sc =
    ScriptContext(
      tx,
      batch_redeemer,
      Withdrawing(Script(swap_intent_proxy_hash)),
    )

  and {
    list.foldl(
      inputs,
      True,
      fn(i, acc) {
        acc && account.account.else(
          ScriptContext(
            tx,
            Delegate(swap_intent_proxy_hash),
            Spending(i.output_reference, Some(dataify(account_state_0))),
          ),
        )
      },
    ),
    intent.batch_intention.else(intent_sc),
  }
}
