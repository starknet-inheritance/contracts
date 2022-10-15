%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_block_number
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

from src.will import Split
from src.will_governable import Signature
from src.will_activable import WillStatusEnum

@contract_interface
namespace Will {
    func inheritance_status() -> (res: felt) {
    }

    func split_of(id: felt) -> (res: Split) {
    }

    func total_splits() -> (res: felt) {
    }

    func start_activation(signatures_len: felt, signatures: Signature*) {
    }

    func stop_activation() {
    }

    func get_splits_id_of(address: felt) -> (res_len: felt, res: felt*) {
    }

    func get_activation_period() -> (res: felt) {
    }
}

@storage_var
func test_contract_address() -> (res: felt) {
}

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar address;
    %{
        ids.address = deploy_contract(
            "src/will.cairo",
            {
                "owner": 1701317860505462169960516548781836103369071457931845363635705241254217018862,
                "activation_period": 86400,
                "splits" : [
                    {   
                        "beneficiary" :666, 
                        "token": 12345, 
                        "percentage": 50,                        
                    },
                    {
                        "beneficiary" : 999, 
                        "token": 12345, 
                        "percentage": 50,                        
                    },
                    {
                        "beneficiary" : 666, 
                        "token": 54321, 
                        "percentage": 50,                        
                    }
                ],
                "threshold": 2,
                "governors_pk": [1656364407783318604687232152713034315607148126855153562038205511454588619784, 658271760697327575889635688962475244047295624929834779174746028751402329037]
            } 
        ).contract_address
    %}
    test_contract_address.write(address);
    return ();
}

@external
func test_initialize_will{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (contract_address) = test_contract_address.read();

    let (total_splits) = Will.total_splits(contract_address=contract_address);
    let (activation_period) = Will.get_activation_period(contract_address=contract_address);

    let (split_1) = Will.split_of(contract_address=contract_address, id=1);
    let (split_2) = Will.split_of(contract_address=contract_address, id=2);

    let (ids_len, ids) = Will.get_splits_id_of(contract_address=contract_address, address=666);

    assert total_splits = 3;
    assert activation_period = 86400;

    assert split_1.beneficiary = 666;
    assert split_1.token = 12345;
    assert split_1.percentage = 50;
    assert split_1.expected_amount.low = 0;

    assert split_2.beneficiary = 999;
    assert split_2.token = 12345;
    assert split_2.percentage = 50;
    assert split_2.expected_amount.low = 0;

    assert ids_len = 2;
    assert ids[0] = 1;
    assert ids[1] = 3;

    return ();
}

@external
func test_start_activation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;

    let (contract_address) = test_contract_address.read();
    let (sign: Signature*) = alloc();

    assert sign[0] = Signature(0x2b94ea0156794006a62fe1bda19e6c32083499d8d13c3a605abc1a5288d6dfe, 0x37116782c568c5cc7a5da13425395a8a17c0ca6babd0b3970637bb7c1113a9f);
    assert sign[1] = Signature(0x64df89530d2cb4a2377c6cff689da1dd54b72d325be44a3ef814f179aa34bde, 0x4c3deeae07ad308b84722340e9878460350c12b517c0087953ae8fe7bfcf6d5);

    Will.start_activation(contract_address=contract_address, signatures_len=2, signatures=sign);

    let (status) = Will.inheritance_status(contract_address);

    assert status = WillStatusEnum.active;

    return ();
}

// not enough signatures == no. of valid sigs < threshold
@external
func test_fail_start_activation_not_enough_signatures{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;

    let (contract_address) = test_contract_address.read();
    let (sign: Signature*) = alloc();

    assert sign[0] = Signature(0x2b94ea0156794006a62fe1bda19e6c32083499d8d13c3a605abc1a5288d6dfe, 0x37116782c568c5cc7a5da13425395a8a17c0ca6babd0b3970637bb7c1113a9f);

    %{ expect_revert(error_message="WillGovernable: not enough valid signatures") %}
    Will.start_activation(contract_address=contract_address, signatures_len=1, signatures=sign);

    return ();
}

@external
func test_stop_activation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    let owner = 0x3c2e96ab980302de2ac92e5da2c643badc4d75d363278bf531aa0c06d7a6dee;

    alloc_locals;
    let (local contract_address) = test_contract_address.read();

    test_start_activation();

    %{ stop_prank = start_prank(ids.owner, ids.contract_address) %}

    Will.stop_activation(contract_address);

    %{ stop_prank() %}

    let (status) = Will.inheritance_status(contract_address);

    assert status = WillStatusEnum.inactive;

    return ();
}

@external
func test_fail_stop_activation_after_activation_period{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    let owner = 0x3c2e96ab980302de2ac92e5da2c643badc4d75d363278bf531aa0c06d7a6dee;

    alloc_locals;
    let (local contract_address) = test_contract_address.read();
    let (local block_number) = get_block_number();

    test_start_activation();

    %{
        stop_prank = start_prank(ids.owner, ids.contract_address)
        stop_warp = warp(ids.block_number + (86400 * 2), ids.contract_address)

        expect_revert(error_message="WillActivable: already past the activation period")
    %}

    Will.stop_activation(contract_address);

    %{
        stop_prank()
        stop_warp()
    %}

    let (status) = Will.inheritance_status(contract_address);

    assert status = WillStatusEnum.inactive;

    return ();
}

@external
func test_claim_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // TODO
    return ();
}

@external
func test_fail_claim_splits_when_will_inactive{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // TODO
    return ();
}
