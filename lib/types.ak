use aiken/crypto.{Signature, VerificationKey, VerificationKeyHash}
use aiken/merkle_patricia_forestry.{Proof}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}

pub type Nonce =
  Int

pub type Magic =
  ByteArray

pub type AccountState {
  /// Must be preserved
  magic: Magic,
  nonce: Int,
  owner: VerificationKey,
  store: Data<ByteArray>,
}

pub type AccountAction {
  EvalIntention
  Withdraw { to: Address }
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
