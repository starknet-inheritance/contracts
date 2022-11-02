%lang starknet

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import deploy, get_caller_address

struct UninitializedSplit {
    beneficiary: felt,
    token: felt,
    percentage: felt,
}

//
// STORAGE VARS
//

@storage_var
func salt() -> (res: felt) {
}

@storage_var
func will_class_hash() -> (res: felt) {
}

//
// EVENTS
//

@event
func will_creation(will_contract_address: felt, owner: felt, will_implementation: felt) {
}

//
// CONSTRUCTOR
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _will_class_hash: felt
) {
    will_class_hash.write(_will_class_hash);
    return ();
}

//
// EXTERNALS
//

@external
func create_will{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    constructor_calldata_len: felt, constructor_calldata: felt*
) -> (will_contract_address: felt) {
    alloc_locals;

    let (current_salt) = salt.read();
    let (caller) = get_caller_address();
    let (class_hash) = will_class_hash.read();

    let (contract_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=constructor_calldata_len,
        constructor_calldata=constructor_calldata,
        deploy_from_zero=0,
    );

    salt.write(current_salt + 1);

    will_creation.emit(
        will_contract_address=contract_address, owner=caller, will_implementation=class_hash
    );

    return (will_contract_address=contract_address);
}

// For demo purposes only
@external
func set_will_class{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_hash: felt
) {
    will_class_hash.write(class_hash);
    return ();
}

//
// VIEWS
//

@view
func get_will_class{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    class_hash: felt
) {
    let (class_hash) = will_class_hash.read();
    return (class_hash=class_hash);
}
