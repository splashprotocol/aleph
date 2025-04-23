use aiken/builtin
use aiken/cbor
use aiken/crypto.{VerificationKeyHash, blake2b_256, verify_ecdsa_signature}
use aiken/merkle_patricia_forestry as mpf
use aiken/primitive/bytearray.{concat}
use cardano/assets.{ada_policy_id}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{InlineDatum, Input, Output}
use constants
use data.{dataify}
use nonce.{check_nonce}
use types.{AccountState, AuthorizedIntention, Intention, Path, Sig}
use value_ext as ext

pub type BatchRedeemer {
  intentions: Data<List<AuthorizedIntention>>,
}

validator batch_witness {
  else(sc: ScriptContext) {
    let ScriptContext { transaction, info, redeemer } = sc
    when info is {
      Withdrawing(_) -> {
        expect BatchRedeemer { intentions } = redeemer
        let intentions = builtin.un_list_data(intentions)
        fold_ios(
          True,
          transaction.inputs,
          transaction.outputs,
          intentions,
          builtin.head_list(transaction.extra_signatories),
          validate_transition,
        )
      }
      Publishing { certificate: RegisterCredential { .. }, .. } -> True
      _ -> fail
    }
  }
}

fn validate_transition(
  input: Input,
  output: Output,
  intent: Data<AuthorizedIntention>,
  account_state: Data<AccountState>,
  operator: VerificationKeyHash,
) -> Bool {
  expect AccountState { nonce, hot_cred, store, .. } as curr_account_state =
    account_state
  expect AuthorizedIntention { intent, remainder: leaving_remainder, auth } =
    intent
  expect InlineDatum(next_account_state) = output.datum
  expect next_account_state: AccountState = next_account_state

  let input = input.output
  let input_value = input.value
  let output_value = output.value

  let Intention {
    leaving_asset,
    leaving_amount,
    arriving_asset,
    expected_arriving_amount,
    fee_lovelace,
    operator: authorised_operator,
    ..
  } = intent

  let (leaving_asset_pol, leaving_asset_tn) = leaving_asset
  let (arriving_asset_pol, arriving_asset_tn) = arriving_asset

  let leaving_asset_is_ada = leaving_asset_pol == ada_policy_id
  let arriving_asset_is_ada = arriving_asset_pol == ada_policy_id

  let (lovelace_input, input_value) = ext.lovelace_of(input_value)
  let (lovelace_output, output_value) = ext.lovelace_of(output_value)

  let (leaving_asset_input, input_value) =
    if leaving_asset_is_ada {
      (lovelace_input, input_value)
    } else {
      ext.quantity_of(input_value, leaving_asset_pol, leaving_asset_tn)
    }
  let (arriving_asset_input, remaining_input_value) =
    if arriving_asset_is_ada {
      (lovelace_input, input_value)
    } else {
      ext.quantity_of(input_value, arriving_asset_pol, arriving_asset_tn)
    }
  let (leaving_asset_output, output_value) =
    if leaving_asset_is_ada {
      (lovelace_output, output_value)
    } else {
      ext.quantity_of(output_value, arriving_asset_pol, arriving_asset_tn)
    }
  let (arriving_asset_output, remaining_output_value) =
    if arriving_asset_is_ada {
      (lovelace_output, output_value)
    } else {
      ext.quantity_of(output_value, arriving_asset_pol, arriving_asset_tn)
    }

  let removed_lovelace = lovelace_input - lovelace_output
  let removed_leaving_asset = leaving_asset_input - leaving_asset_output
  let added_arriving_asset = arriving_asset_output - arriving_asset_input

  let fee_remainder = leaving_remainder * fee_lovelace / leaving_amount
  let fee_consumed = fee_lovelace - fee_remainder
  let fee_from_leaving_asset =
    if leaving_asset_is_ada {
      fee_consumed
    } else {
      0
    }
  let fee_from_arriving_asset =
    if arriving_asset_is_ada {
      fee_consumed
    } else {
      0
    }
  let leaving_asset_removed_without_fee =
    removed_leaving_asset - fee_from_leaving_asset
  let arriving_asset_added_without_fee =
    added_arriving_asset + fee_from_arriving_asset
  let declared_remainder_ok =
    leaving_asset_removed_without_fee == leaving_amount - leaving_remainder
  let exchange_ok =
    leaving_asset_removed_without_fee * expected_arriving_amount <= arriving_asset_added_without_fee * leaving_amount
  let fee_ok =
    if leaving_asset_is_ada || arriving_asset_is_ada {
      True
    } else {
      removed_lovelace <= fee_consumed
    }

  let intent_nonce = intent.target_nonce
  let intent_bytes = intent |> cbor.serialise

  let has_remainder = leaving_remainder > 0

  let auth_ok =
    when auth is {
      Path(proof) -> {
        let store = store |> builtin.un_b_data |> mpf.from_root
        let intent_digest = intent_bytes |> blake2b_256
        let intent_key = cbor.serialise(intent_nonce)
        expect proof: mpf.Proof = proof
        if has_remainder {
          let updated_intent =
            Intention {
              ..intent,
              leaving_amount: leaving_remainder,
              expected_arriving_amount: expected_arriving_amount - arriving_asset_added_without_fee,
              fee_lovelace: fee_lovelace - fee_consumed,
            }
          let updated_intent_digest =
            updated_intent |> cbor.serialise |> blake2b_256
          let next_account_store =
            next_account_state.store |> builtin.un_b_data |> mpf.from_root
          (mpf.update(
            store,
            intent_key,
            proof,
            intent_digest,
            updated_intent_digest,
          ) == next_account_store)?
        } else {
          mpf.has(store, intent_key, intent_digest, proof)?
        }
      }
      Sig { prefix, postfix, signature, update_proof } -> {
        let nonce_ok =
          check_nonce(
            builtin.un_list_data(nonce),
            builtin.un_list_data(next_account_state.nonce),
            intent_nonce.1st,
            intent_nonce.2nd,
          )
        let message =
          intent_bytes
            |> concat(builtin.un_b_data(prefix), _)
            |> concat(builtin.un_b_data(postfix))
            |> blake2b_256
        let main_signature_ok =
          verify_ecdsa_signature(
            hot_cred.1st |> builtin.un_b_data,
            message,
            builtin.un_b_data(signature),
          )
        let co_cred = hot_cred.2nd
        let co_signature_ok =
          if co_cred != dataify([]) {
            verify_ecdsa_signature(
              co_cred |> builtin.un_b_data,
              message,
              builtin.un_b_data(signature),
            )
          } else {
            True
          }
        let continuation_ok =
          if has_remainder {
            let intent_key = cbor.serialise(intent_nonce)
            let updated_intent =
              Intention {
                ..intent,
                leaving_amount: leaving_remainder,
                expected_arriving_amount: expected_arriving_amount - arriving_asset_added_without_fee,
                fee_lovelace: fee_lovelace - fee_consumed,
              }
            let updated_intent_digest =
              updated_intent |> cbor.serialise |> blake2b_256
            let store = store |> builtin.un_b_data |> mpf.from_root
            let next_account_store =
              next_account_state.store |> builtin.un_b_data |> mpf.from_root
            expect proof: mpf.Proof = update_proof
            (mpf.insert(store, intent_key, updated_intent_digest, proof) == next_account_store)?
          } else {
            True
          }
        nonce_ok? && main_signature_ok? && co_signature_ok? && continuation_ok?
      }
    }

  let next_state_ok = and {
      next_account_state.magic == constants.account_magic,
      curr_account_state.allowlist == next_account_state.allowlist,
      curr_account_state.hot_cred == next_account_state.hot_cred,
      curr_account_state.cold_cred == next_account_state.cold_cred,
    }

  and {
    (remaining_input_value == remaining_output_value)?,
    (operator == authorised_operator)?,
    next_state_ok?,
    declared_remainder_ok?,
    exchange_ok?,
    fee_ok?,
    auth_ok?,
  }
}

fn fold_ios(
  acc: Bool,
  inputs: List<Input>,
  outputs: List<Output>,
  intents: List<Data<AuthorizedIntention>>,
  authorised_operator: VerificationKeyHash,
  predicate: fn(
    Input,
    Output,
    Data<AuthorizedIntention>,
    Data<AccountState>,
    VerificationKeyHash,
  ) ->
    Bool,
) -> Bool {
  when inputs is {
    [] -> acc
    [input, ..inputs] ->
      when outputs is {
        [] -> False
        [output, ..outputs] ->
          when input.output.datum is {
            InlineDatum(datum) -> {
              let magic = datum |> builtin.unconstr_fields |> builtin.head_list
              if constants.account_magic == magic {
                when intents is {
                  [] -> False
                  [intent, ..intents] ->
                    fold_ios(
                      acc && predicate(
                        input,
                        output,
                        intent,
                        datum,
                        authorised_operator,
                      ),
                      inputs,
                      outputs,
                      intents,
                      authorised_operator,
                      predicate,
                    )
                }
              } else {
                fold_ios(
                  acc,
                  inputs,
                  outputs,
                  intents,
                  authorised_operator,
                  predicate,
                )
              }
            }
            _ -> True
          }
      }
  }
}
