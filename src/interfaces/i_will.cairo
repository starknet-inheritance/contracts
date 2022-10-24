%lang starknet

from starkware.cairo.common.uint256 import Uint256

struct Split {
    beneficiary: felt,
    token: felt,
    percentage: felt,
    expected_amount: Uint256,
}

struct Signature {
    r: felt,
    s: felt,
}

@contract_interface
namespace IWill {
    // Starts the activation process given a list of valid signatures which
    // as longs as `valid signatures >= signatures threshold`
    func start_activation(signatures_len: felt, signatures: Signature*) {
    }

    // Stops the activation process (only the owner is allowed to perform this).
    //
    // Can only be done during the activation period. If not stopped before the period
    // ends, the Will become claimable.
    func stop_activation() {
    }

    // Claim split by given its ID
    //
    // Will only succeed if split's beneficiary == caller
    func claim_split(id: felt) {
    }

    // Returns the IDs of the splits that belong to user of address `address`
    func get_splits_id_of(address: felt) -> (res_len: felt, res: felt*) {
    }

    // Returns the splits information given its `id`
    func split_of(id: felt) -> (res: Split) {
    }

    // Returns the Will status.
    //
    // Possible values :-
    //      0 - inactive.It has not been activated yet (start_activation hasn't been called or activation process has been rejected).
    //      1 - pending. Activation process is ongoing.
    //      2 - active. Already past the activation process and at least 1 split has been claimed. (NOTE: will only return `active` if someone has claimed a split)
    func inheritance_status() -> (status: felt) {
    }

    // Returns the total number of claimable splits
    func total_splits() -> (res: felt) {
    }

    // Returns the time it takes for the activation period to end after it has been started
    func get_activation_period() -> (res: felt) {
    }

    // Returns the details of all splits
    func get_all_splits() -> (splits_len: felt, splits: Split*) {
    }
}
