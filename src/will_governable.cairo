%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.signature import check_ecdsa_signature
from starkware.starknet.common.syscalls import get_tx_info, TxInfo
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, EcOpBuiltin

const SIGN_MESSAGE = 'MESSAGE';

struct Signature {
    r: felt,
    s: felt,
}

@storage_var
func WillGovernable_total_governors() -> (res: felt) {
}

@storage_var
func WillGovernable_governors(id: felt) -> (address: felt) {
}

@storage_var
func WillGovernable_threshold() -> (res: felt) {
}

namespace WillGovernable {
    // - Initialize governors public key which will later be used for verifying signatures
    func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        threshold: felt, governors_pk_len: felt, governors_pk: felt*
    ) {
        WillGovernable_threshold.write(threshold);
        WillGovernable_total_governors.write(governors_pk_len);

        _initialize_governors_loop(governors_pk_len, governors_pk);

        return ();
    }

    // - Will only pass if valid signatures >= threshold
    // - This function runs in O(signatures_len * threshold)
    // - Signature = sign(SIGN_MESSAGE)
    func verify_signatures{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
    }(signatures_len: felt, signatures: Signature*) {
        // let (tx: TxInfo*) = get_tx_info();

        _verify_signatures_loop(SIGN_MESSAGE, 0, signatures_len, signatures);

        return ();
    }

    func total_governors{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        res: felt
    ) {
        return WillGovernable_total_governors.read();
    }

    func get_all_governors_pk{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (res_len: felt, res: felt*) {
        alloc_locals;
        let (res: felt*) = alloc();

        _get_all_governors_loop(0, res);

        let (max) = WillGovernable_total_governors.read();

        return (max, res);
    }

    func threshold{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        res: felt
    ) {
        return WillGovernable_threshold.read();
    }

    func governor_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: felt) -> (
        res: felt
    ) {
        let (res) = WillGovernable_governors.read(id);
        return (res=res);
    }
}

func _verify_signatures_loop{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}(SIGN_MESSAGE: felt, valid_count: felt, signatures_len: felt, signatures: Signature*) {
    alloc_locals;

    let (threshold) = WillGovernable.threshold();

    if (valid_count == threshold) {
        return ();
    }

    if (signatures_len == 0) {
        // check that `valid_count` must be equal or bigger than threshold
        // else revert
        with_attr error_message("WillGovernable: not enough valid signatures") {
            assert_le(threshold, valid_count);
        }

        return ();
    }

    let (pk_len, pk: felt*) = WillGovernable.get_all_governors_pk();

    // iterate over all governors pk to check whether the signature
    // belongs to one of them
    let is_valid = _check_sign_with_governors_pub_key_loop(
        SIGN_MESSAGE, signatures.r, signatures.s, pk_len, pk
    );

    if (is_valid == TRUE) {
        _verify_signatures_loop(
            SIGN_MESSAGE, valid_count + 1, signatures_len - 1, signatures + Signature.SIZE
        );
    } else {
        _verify_signatures_loop(
            SIGN_MESSAGE, valid_count, signatures_len - 1, signatures + Signature.SIZE
        );
    }

    return ();
}

func _check_sign_with_governors_pub_key_loop{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}(SIGN_MESSAGE: felt, sign_r: felt, sign_s: felt, pub_keys_len: felt, pub_keys: felt*) -> felt {
    alloc_locals;

    if (pub_keys_len == 0) {
        return FALSE;
    }

    let pk = pub_keys[pub_keys_len - 1];

    let (local is_valid) = check_ecdsa_signature(SIGN_MESSAGE, pk, sign_r, sign_s);

    if (is_valid == TRUE) {
        return TRUE;
    } else {
        return _check_sign_with_governors_pub_key_loop(
            SIGN_MESSAGE, sign_r, sign_s, pub_keys_len - 1, pub_keys
        );
    }
}

func _initialize_governors_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    governors_pk_len: felt, governors_pk: felt*
) {
    if (governors_pk_len == 0) {
        return ();
    }

    let current_pk = governors_pk[governors_pk_len - 1];
    WillGovernable_governors.write(governors_pk_len, current_pk);

    _initialize_governors_loop(governors_pk_len - 1, governors_pk);

    return ();
}

func _get_all_governors_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arr_len: felt, arr: felt*
) -> (res_len: felt, res: felt*) {
    let (max) = WillGovernable_total_governors.read();

    if (arr_len == max) {
        return (arr_len, arr);
    }

    // because when governors were set, index started from 1
    let (pk) = WillGovernable_governors.read(arr_len + 1);
    assert arr[arr_len] = pk;

    return _get_all_governors_loop(arr_len + 1, arr);
}
