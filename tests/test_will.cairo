%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

from src.will import Split
from src.will_governable import Signature

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

    func count_splits_of(address: felt) -> (res: felt) {
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
                "splits" : [
                    {   
                        "beneficiary" :666, 
                        "token": 12345, 
                        "amount": 69
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
    let (split) = Will.split_of(contract_address=contract_address, id=1);

    assert total_splits = 1;
    assert split.beneficiary = 666;
    assert split.token = 12345;
    assert split.amount = 69;

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
