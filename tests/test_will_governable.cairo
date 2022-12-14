%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, EcOpBuiltin

from src.will_governable import WillGovernable, Signature

@external
func test_initialize_governors{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    let threshold = 2;
    let (arr: felt*) = alloc();

    assert arr[0] = 0x764d93d848182c8da44b7fa236b6aa584410676cc0fdb2b92ff8e741181bed0;
    assert arr[1] = 0x3a978127dc59562b9f244c639a3bed25464220872b5ae9f2736b995651f4c08;

    WillGovernable.initialize(threshold, 2, arr);

    let (total) = WillGovernable.total_governors();
    let (_threshold) = WillGovernable.threshold();
    let (pk_1) = WillGovernable.governor_of(1);
    let (pk_2) = WillGovernable.governor_of(2);
    let (len, res: felt*) = WillGovernable.get_all_governors_pk();

    assert total = 2;
    assert _threshold = threshold;
    assert pk_1 = arr[0];
    assert pk_2 = arr[1];
    assert len = 2;

    assert res[0] = arr[0];
    assert res[1] = arr[1];

    return ();
}

@external
func test_verify_governors_multisig{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}() {
    alloc_locals;

    let (arr: felt*) = alloc();

    assert arr[0] = 0x3a978127dc59562b9f244c639a3bed25464220872b5ae9f2736b995651f4c08;
    assert arr[1] = 0x764d93d848182c8da44b7fa236b6aa584410676cc0fdb2b92ff8e741181bed0;
    assert arr[2] = 0x1749190a2d2724b685327d695bab1e1afc5749f1b94e1a5e53f2509006863cd;

    WillGovernable.initialize(2, 3, arr);

    let (sign: Signature*) = alloc();

    assert sign[0] = Signature(0x2b94ea0156794006a62fe1bda19e6c32083499d8d13c3a605abc1a5288d6dfe, 0x37116782c568c5cc7a5da13425395a8a17c0ca6babd0b3970637bb7c1113a9f);
    assert sign[1] = Signature(0x64df89530d2cb4a2377c6cff689da1dd54b72d325be44a3ef814f179aa34bde, 0x4c3deeae07ad308b84722340e9878460350c12b517c0087953ae8fe7bfcf6d5);

    WillGovernable.verify_signatures(2, sign);

    return ();
}

@external
func test_fail_verify_governors_multisig_with_not_enough_valid_sign{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}() {
    alloc_locals;

    let (arr: felt*) = alloc();

    assert arr[0] = 0x3a978127dc59562b9f244c639a3bed25464220872b5ae9f2736b995651f4c08;
    assert arr[1] = 0x764d93d848182c8da44b7fa236b6aa584410676cc0fdb2b92ff8e741181bed0;
    assert arr[2] = 0x1749190a2d2724b685327d695bab1e1afc5749f1b94e1a5e53f2509006863cd;

    WillGovernable.initialize(2, 3, arr);

    let (sign: Signature*) = alloc();

    assert sign[0] = Signature(0x64df89530d2cb4a2377c6cff689da1dd54b72d325be44a3ef814f179aa34bde, 0x4c3deeae07ad308b84722340e9878460350c12b517c0087953ae8fe7bfcf6d5);

    %{ expect_revert(error_message="WillGovernable: not enough valid signatures") %}

    WillGovernable.verify_signatures(1, sign);

    return ();
}
