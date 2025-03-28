use account
use aiken/cbor
use aiken/crypto.{blake2b_256}
use cardano/address.{Address, Script}
use cardano/assets.{ada_asset_name, ada_policy_id, add, from_lovelace}
use cardano/script_context.{ScriptContext, Spending, Withdrawing}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use constants.{account_magic}
use intent.{BatchRedeemer}
use types.{AccountState, AuthorizedIntention, Intention, Sig}

const null_hash =
  #"0000000000000000000000000000000000000000000000000000000000000000"

test exec_intent_atomic() {
  let operator = "operator"
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState { magic: account_magic, nonce: 0, owner, store: null_hash }
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
    AccountState { magic: account_magic, nonce: 1, owner, store: null_hash }
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
      ..transaction.placeholder,
      inputs: inputs,
      outputs: outputs,
      extra_signatories: [operator],
      withdrawals: [Pair(Script(account.intent_proxy_hash), 0)],
    }

  let account_sc =
    ScriptContext(
      tx,
      [],
      Spending(account_in_ref, Some(intent.dataify(account_state_0))),
    )

  let intent_1 =
    Intention {
      nonce: 0,
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
        signature: #"59df81675843a4fa8299eb7580f163e604b8765e37a9c921dee5f01301ea654f0d3a1587ae1d87bc48685aeb4c7bfe2baf2c3d73b53d430a332ec4f2a0961890",
        update_proof: [],
      },
    }
  let batch_redeemer = BatchRedeemer { intentions: [auth_intent_1] }

  let intent_sc =
    ScriptContext(
      tx,
      batch_redeemer,
      Withdrawing(Script(account.intent_proxy_hash)),
    )

  and {
    account.account.else(account_sc),
    intent.batch_intention.else(intent_sc),
  }
}

// fn sig() {
//     use secp256k1::{Secp256k1, Message, SecretKey, PublicKey};

//     let secp = Secp256k1::new();
//     let secret_key = SecretKey::from_slice(&[0xcd; 32]).expect("32 bytes, within curve order");
//     let public_key = PublicKey::from_secret_key(&secp, &secret_key);
//     println!("public key: {}", hex::encode(public_key.serialize()));
//     let message = Message::from_digest(<[u8;32]>::try_from(hex::decode("F4C6DA9CB58869F410C330E60F501E560E7AD3632288C8B181F503ED1AB35C65").unwrap()).unwrap());

//     let sig = secp.sign_ecdsa(&message, &secret_key);
//     println!("sig: {}", hex::encode(sig.serialize_compact()));
//     assert!(secp.verify_ecdsa(&message, &sig, &public_key).is_ok());
// }

test exec_intent_continous() {
  let operator = "operator"
  let owner =
    #"02b98a7fb8cc007048625b6446ad49a1b3a722df8c1ca975b87160023e14d19097"
  let account_address = Address(Script("account_address"), None)
  let account_state_0 =
    AccountState { magic: account_magic, nonce: 0, owner, store: null_hash }
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
      nonce: 1,
      owner,
      store: #"4b7f9095ddcc26e13a3bae5af26991fadbe1c9a9ee10fcf0849ec15709cac845",
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
      ..transaction.placeholder,
      inputs: inputs,
      outputs: outputs,
      extra_signatories: [operator],
      withdrawals: [Pair(Script(account.intent_proxy_hash), 0)],
    }

  let account_sc =
    ScriptContext(
      tx,
      [],
      Spending(account_in_ref, Some(intent.dataify(account_state_0))),
    )

  let intent_1 =
    Intention {
      nonce: 0,
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
        signature: #"59df81675843a4fa8299eb7580f163e604b8765e37a9c921dee5f01301ea654f0d3a1587ae1d87bc48685aeb4c7bfe2baf2c3d73b53d430a332ec4f2a0961890",
        update_proof: [],
      },
    }
  let batch_redeemer = BatchRedeemer { intentions: [auth_intent_1] }

  let intent_sc =
    ScriptContext(
      tx,
      batch_redeemer,
      Withdrawing(Script(account.intent_proxy_hash)),
    )

  and {
    account.account.else(account_sc),
    intent.batch_intention.else(intent_sc),
  }
}
