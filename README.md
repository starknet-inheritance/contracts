## WILL FACTORY CONTRACT

**Contract address (Goerli) :**

```
0x01f51fca15fe380093c6cb81146767cbc2e109e1c9e20940bf9ba7fb9d4e38b0
```

View on [StarkScan](https://testnet.starkscan.co/contract/0x01f51fca15fe380093c6cb81146767cbc2e109e1c9e20940bf9ba7fb9d4e38b0#overview) ↗️

_`constructor_calldata` in `create_will()` should be arranged like below but as an array of `felt` instead :_

```
owner: felt,
activation_period: felt,
threshold: felt,
governors_pk_len: felt,
governors_pk: felt*,
splits_len: felt,
splits: UninitializedSplit*,
```

**Demo Contract (Goerli) :**

```
0x05131a9a5dd8f44505f8ce8760b8f076b5732cec3accdee5f17dbf70a300f1bf
```

View on [StarkScan](https://testnet.starkscan.co/contract/0x05131a9a5dd8f44505f8ce8760b8f076b5732cec3accdee5f17dbf70a300f1bf#overview) ↗️

_Same calldata but without the `activation_period` as it is already hardcoded in the contract._

## WILL CLASS

**Class hash (Goerli) :**

```
0x419d6a47ce30eb2b3657d90341c76b0a68455be1921988ea357c933d1addfd2
```

View on [StarkScan](https://testnet.starkscan.co/class/0x419d6a47ce30eb2b3657d90341c76b0a68455be1921988ea357c933d1addfd2#overview) ↗️

**Demo Class Hash (Goerli) :**

```
0x06054dac328c26e8655fc8a1a86946c5156bab6b234ff347fc5b38bc8b6dae1d
```

View on [StarkScan](https://testnet.starkscan.co/class/0x06054dac328c26e8655fc8a1a86946c5156bab6b234ff347fc5b38bc8b6dae1d#overview) ↗️

## ACCOUNT CLASS

Because the Will contract needs to check for an account's activity status, as such the current implementation expects a Will's owner account to provide a way to query the timestamp of the latest transaction executed from that account contract.

The implementation of the [account contract](https://github.com/starknet-inheritance/contracts/blob/main/src/account/argent_account_tx_tt.cairo) which satisfies such requirement is modified from [v0.9.0 Cairo of Argent's account contract](https://github.com/argentlabs/argent-contracts-starknet/tree/cairo/v0.9.0) and can be used by upgrading your account to the provided class hash below.

**Class hash (Goerli) :**

```
0x03c3c2d163db7e855e3fb025ea58e86660a7ba16c8a8b528608af5e5138597d0
```

View on [StarkScan](https://testnet.starkscan.co/class/0x03c3c2d163db7e855e3fb025ea58e86660a7ba16c8a8b528608af5e5138597d0#overview) ↗️

---

## Updates:

#1 Contract created
https://testnet.starkscan.co/contract/0x01ad0df75c076e5433f1ee9b336634d201f651c15c583a0b50ce15ebbd9e13b9#read-contract
