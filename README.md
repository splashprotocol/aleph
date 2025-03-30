# Account abstraction over UTxO

## Building

```sh
aiken build
```

## Testing

To run all tests, simply do:

```sh
aiken check
```

## Signign intents off-chain

```rust
use secp256k1::{Secp256k1, Message, SecretKey, PublicKey};

let secp = Secp256k1::new();
let secret_key = SecretKey::from_slice(&[0xcd; 32]).expect("32 bytes, within curve order");
let public_key = PublicKey::from_secret_key(&secp, &secret_key);
println!("public key: {}", hex::encode(public_key.serialize()));
// If the supplied byte slice was *not* the output of a cryptographic hash function this would
// be cryptographically broken. It has been trivially used in the past to execute attacks.
let message = Message::from_digest(<[u8;32]>::try_from(hex::decode("F3ED7593CEB7D8F42A3020DBA87226B3450DAE488B1D0A2E1FA4BB6E29F09368").unwrap()).unwrap());

let sig = secp.sign_ecdsa(&message, &secret_key);
println!("sig: {}", hex::encode(sig.serialize_compact()));
assert!(secp.verify_ecdsa(&message, &sig, &public_key).is_ok());
```