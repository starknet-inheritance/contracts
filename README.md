Because the Will contract needs to check for an account's activity status, as such the current implementation expects a Will's owner account to provide a way to query the timestamp of the latest transaction executed from that account contract.

The implementation of the account contract which satisfies such requirement is modified from [version 0.2.0 of Argent's account contract](https://github.com/argentlabs/argent-contracts-starknet/tree/cairo/v0.9.0) and can be used using the provided class hash.

**Class hash (Goerli) :**

```
0x03c3c2d163db7e855e3fb025ea58e86660a7ba16c8a8b528608af5e5138597d0
```
