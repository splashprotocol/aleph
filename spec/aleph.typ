#set page(margin: 1.4in)
#show par: set block(spacing: 0.65em)
#set par(leading: 0.65em, first-line-indent: 1.8em, justify: true)
#set text(font: "STIX Two Text", size: 10pt)
#set heading(numbering: "1.")

#set math.equation(block: true, numbering: "(1)")
#show math.equation: set block(spacing: 1em)

#show ref: it => {
  if it.element != none and it.element.func() == math.equation {
    // Override equation references.
    link(it.element.location(), numbering(
      it.element.numbering,
      ..counter(math.equation).at(it.element.location())
    ))
  } else {
    // Other references as usual.
    it
  }
}

#let cprod = math.class(
  "relation",
  sym.times.circle,
)
#let csum = math.class(
  "relation",
  sym.plus.circle,
)
#let null = sym.emptyset.rev


#align(center, text(17pt)[
  *Aleph: Account Abstraction over UTxO*
])

#grid(
  columns: (1fr),
  align(center)[
    SpectrumLabs \
    #link("mailto:info@spectrumlabs.fi")
  ]
)

#align(center)[
  #set par(justify: true)
  #grid(
    columns: (80%),
    [
      *Abstract* \
      UTxO model is known for its determinism which implies that all effects of a transaction are known in advance. 
      For applications that deal with shared on-chain resources such as AMM pools or CLOB this property implies 
      certain design limitations that, if addressed in a naive way result in significant overhead. A more efficient 
      approach to these limitations was previously introduced in Spectrum Bloom paper, in this work we describe the 
      implementation of that concept referred to as Autonomous Accounts, or more known as Account Abstraction over 
      UTxO on Cardano blockchain. \
    ],
  )
]

= Structure
First we revisit the problem and the solution proposed in Spectrum Bloom paper, then proceed to technical details of implementation on top of Cardano.

= Introduction

eUTxO pioneers faced a challenge when first tried to port protocols such as
Uniswap: while EVM implementations allowed its users to transact with
liquidity pools directly from clients, on eUTxO such scenario was extremely
impractical. The root of the problem lays in the nature of eUTxO, unlike
"Account" model it requires that all inputs of a transaction are determinis-
tic. Therefore, direct transaction with shared, atomic on-chain resources (e.g. liquidity pools) would result in 
race conditions. A classical approach to the aforementioned issue is to synchronize user
access to a shared resource via on-chain orders which are then picked
up, ordered and executed by off-chain agents shortly after. On-chain order is
encoded into a UTxO carrying some input value (e.g. some amount of base
asset in case of limit sell order) and guarded with a validator script that 
ensures that the order is executed at a fair price provided by concrete liq-
uidity pool at the time of actual order execution.

#figure(
  image("assets/old_order.png", width: 75%),
  caption: [A diagram that shows how users interact with aggregated liquidity
pools via orders. At first step a client publishes an order moving some of
his funds into it, at the next step an off-chain operator matches this
order with a proper pool and executes the exchange.]
)

Classical approach is inefficient. On-chain orders require an extra transaction. As a result
user has to cover fees for both order publishing transaction and execution
transaction. Additionally, moving or canelling orders requires a separate 
transaction as well what draws bad user experience.

= Account Abstraction

The proposed solution is to create a virtual transaction system on top of UTxO that would 
only require off-chain specification (aka Intentions) of the desired outputs without too many on-chain details.
In order for intentions to work we need an on-chain entities (aka Accounts) capable of interpreting them in a safe
way and release funds when needed.

#figure(
  image("assets/intents.png", width: 75%),
  caption: [Account Abstraction. Intents are similar to on-chain orders, but live off-chain and create nearly zero overhead]
)

== Aleph

Aleph is designed with the following principles in mind:
- *Security*. Gurantees provided by the base layer (Cardano) must not be compromised
- *Composability*. Account should be able to inteact with arbitrary applications
- *Efficiency*. Account design should allow for transacting with many accounts in one on-chain transaction

=== Account

We model account as an on-chain entity encoded into UTxO. Account UTxO holds some non-zero balance of assets, 
equipped with a state (@account_state) and guarded by a simple script that has two paths of execution:
- *Direct spending*. User can spend account UTxO directly by signing transaction with a key corresponding to "cold_cred"
- *Delegate to a witness*. Leak control to a witness script listed in "allowlist"

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    stroke: none,
    [*Field*], [*Type*], [*Description*],
    [magic], [`ByteArray`], [Used to recognize accounts],
    [allowlist], [`List<ScriptHash>`], [Set of allowed delegatees],
    [nonce], [`List<Nonce>`], [$N$ independent monotonically increasing counters used to protect the account from replay attacks],
    [hot_cred], [`(VerificationKey, Option<VerificationKey>)`], [Credentials used to authorize intents. Composed of a main credential and an optional co-credential],
    [cold_cred], [`VerificationKeyHash`], [Credential for direct spending],
    [store], [`ByteArray`], [Local store of the account, used by dapps to save intermediate state. Represented as a root hash of Merkle Patricia Tree],
  ),
  caption: [Account state. All fields except `magic` are mutable.]
) <account_state>

=== Witness

A witness script does all the magic that makes account abstraction appealing. Although implementations of overall witness may vary, all of them must perform the following validations:
- For all involved accounts check that all fields of the state are preserved except "nonce" and "store" 
- For all involved accounts validate authorization of applied intents
- For all involved accounts validate intent spcific rules. This part is implementation specific, e.g in case of witness that models limit orders the validations would apply to exchange rate, trader fees etc.

Scripts that do not perform all the neccessary validation must not be added to "allowlist".
The design choice of placing critical validations into witnesses sacrifices convenience for developers in favor of 
efficiency: having all validations in one witness allows for batch validation in one pass (see @batch_witness).

#figure(
  image("assets/witness.png", width: 60%),
  caption: [Batch witness. Transitions of all accounts involved are validated in one pass]
) <batch_witness>

=== Intent

Intent structure is an implementation detail in Aleph and each dapp integrating with accounts can have its own 
structure assuming their witness implementation knows how to work with that type of intent. Some fields are 
mandatory, though: "TargetNonce" - is a maximum value of account state "nonce" at the given "NonceIndex". Although 
account nonce system allows for parallelization of a limited factor $N$ (in practice $1<=N<=5$), some applications 
may dismiss nonces completely to sacrifice on-chain gurantees in favor of maximum parallelization and cost 
efficiency.

#figure(
  table(
    columns: (auto, auto),
    stroke: none,
    align: (right, left),
    [TargetNonce =], [NonceIndex × Nonce],
    [Intent =], [IntentParams × TargetNonce],
    [AuthorisedIntent =], [Intent × σ],
  ),
  caption: [Intent structure. User authorizes the intent by signing its contents and attaching the proof σ. IntentParams – parameters of the order, e.g. quote and base asset, price, etc., Nonce – monotonically increasing counter to prevent replay attacks.]
) <intent>