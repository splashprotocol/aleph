use aiken/crypto.{ScriptHash, Signature, VerificationKey, VerificationKeyHash}
use aiken/merkle_patricia_forestry.{Proof}
use cardano/assets.{AssetName, PolicyId}

pub type Nonce =
  Int

pub type Magic =
  ByteArray

pub type AccountState {
  /// Must be preserved
  magic: Magic,
  allowlist: Data<List<ScriptHash>>,
  nonce: Int,
  owner: Data<VerificationKey>,
  store: Data<ByteArray>,
}

pub type AccountAction {
  /// Delegate control to third-party intent witness
  Delegate(Data<ScriptHash>)
  /// Direct operation carried by owner 
  Direct
}

pub type Intention {
  nonce: Nonce,
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
