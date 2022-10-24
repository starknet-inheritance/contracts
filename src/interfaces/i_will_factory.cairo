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
    // The calldata should have all this details EXACTLY in this order.
    //
    // `activation_period`
    //      How long should the activation period be before the will
    //      can be claimed (provided it doesn't get rejected by owner during that period).
    //
    // `activation_threshold`
    //      The amount of valid signatures required to start the activation process.
    //
    // `governors_pk_len`
    //      Total number of governors_pk
    //
    // `governors_pk`
    //      - List of governors public keys (a.k.a the public key of the users whose signatures are eligible
    //        to start the activation process).
    //      - The public keys will be used to verify the signatures.
    //
    // `splits_len`
    //      Total splits
    //
    // `splits`
    //      List of splits
    //
    func create_will(constructor_calldata_len: felt, constructor_calldata: felt*) -> (
        will_contract_address: felt
    ) {
    }
}
