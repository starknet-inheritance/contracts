%lang starknet

struct UninitializedSplit {
    beneficiary: felt,
    token: felt,
    percentage: felt,
}

@contract_interface
namespace IWillFactory {
    //
    // Deploys a Will contract initialized with the given information.
    // Will contract owner is automatically derived from this function caller.
    //
    // `activation_period`
    //      How long should the activation period be before the will
    //      can be claimed (provided it doesn't get rejected by owner during that period).
    //
    // `activation_threshold`
    //      The amount of valid signatures required to start the activation process.
    //
    // `splits`
    //      List of splits
    //
    // `governors_pk`
    //      - List of governors public keys (a.k.a the public key of the users whose signatures are eligible
    //        to start the activation process).
    //      - The public keys will be used to verify the signatures.
    //
    func create_will(
        activation_period: felt,
        activation_threshold: felt,
        splits_len: felt,
        splits: UninitializedSplit*,
        governors_pk_len: felt,
        governors_pk: felt*,
    ) {
    }
}
