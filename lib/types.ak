use aiken/crypto.{ScriptHash, Signature, VerificationKey, VerificationKeyHash}
use aiken/merkle_patricia_forestry.{Proof}
use cardano/assets.{AssetName, PolicyId}

pub type Nonce =
  Int

pub type Magic =
  ByteArray

pub type AccountState {
  /// Used to recognise accounts
  magic: Data<Magic>,
  /// Set of allowed delegatees
  allowlist: Data<List<ScriptHash>>,
  /// Monotonically increasing counter used to protect account from replay attacks 
  nonce: Data<Int>,
  /// Credentials used to authorize intents. main cred and an optional co-cred
  hot_cred: (Data<VerificationKey>, Data<VerificationKey>),
  /// Credential for direct spening
  cold_cred: Data<VerificationKeyHash>,
  /// Local store of the account used by dapps to save intermediate state
  store: Data<ByteArray>,
}

pub type AccountAction {
  /// Delegate control to third-party intent witness
  Delegate(Data<ScriptHash>)
  /// Direct operation carried by owner 
  Direct
}

pub type Intention {
  target_nonce: Nonce,
  leaving_asset: (PolicyId, AssetName),
  leaving_amount: Int,
  arriving_asset: (PolicyId, AssetName),
  expected_arriving_amount: Int,
  fee_lovelace: Int,
  operator: VerificationKeyHash,
}

pub type Auth {
  Path(Data<Proof>)
  Sig {
    prefix: Data<ByteArray>,
    postfix: Data<ByteArray>,
    signature: Data<Signature>,
    update_proof: Data<Proof>,
  }
}

pub type AuthorizedIntention {
  intent: Intention,
  remainder: Int,
  auth: Auth,
}
