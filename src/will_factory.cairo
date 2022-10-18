%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import deploy, get_caller_address

struct UninitializedSplit {
    beneficiary: felt,
    token: felt,
    percentage: felt,
}

@storage_var
func salt() -> (res: felt) {
}

@storage_var
func will_class_hash() -> (res: felt) {
}

@event
func will_creation(contract_address: felt, owner: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _will_class_hash: felt
) {
    will_class_hash.write(_will_class_hash);
    return ();
}

@external
func create_will{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    activation_period: felt,
    activation_threshold: felt,
    splits_len: felt,
    splits: UninitializedSplit*,
    governors_pk_len: felt,
    governors_pk: felt*,
) -> (will_contract_address: felt) {
    let (current_salt) = salt.read();
    let (caller) = get_caller_address();
    let (class_hash) = will_class_hash.read();

    tempvar constructor_calldata = new (
        caller,
        activation_period,
        activation_threshold,
        splits_len,
        splits,
        governors_pk_len,
        governors_pk,
        );

    let (contract_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=7,
        constructor_calldata=cast(constructor_calldata, felt*),
        deploy_from_zero=0,
    );

    salt.write(current_salt + 1);

    will_creation.emit(contract_address=contract_address, owner=caller);

    return (will_contract_address=contract_address);
}
