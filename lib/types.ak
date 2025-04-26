use aiken/crypto.{Signature}
use aiken/merkle_patricia_forestry.{Proof}

pub type Nonce =
  Int

pub type Magic =
  ByteArray

pub type Auth {
  Path(Data<Proof>)
  Sig {
    prefix: Data<ByteArray>,
    postfix: Data<ByteArray>,
    signature: Data<Signature>,
    update_proof: Data<Proof>,
  }
}
