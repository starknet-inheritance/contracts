%lang starknet

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.will import Split, UninitializedSplit

@contract_interface
namespace WillFactory {
    func create_will(constructor_calldata_len: felt, constructor_calldata: felt*) {
    }

    func get_will_class() -> (class_hash: felt) {
    }
}

@contract_interface
namespace Will {
    func claim_split(id: felt) {
    }

    func inheritance_status() -> (res: felt) {
    }

    func split_of(id: felt) -> (res: Split) {
    }

    func total_splits() -> (res: felt) {
    }

    func get_splits_id_of(address: felt) -> (res_len: felt, res: felt*) {
    }

    func get_activation_period() -> (res: felt) {
    }
}

@storage_var
func will_factory_address() -> (res: felt) {
}

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar address;
    tempvar class_hash;

    %{
        ids.class_hash = declare("src/will.cairo").class_hash
        ids.address = deploy_contract("src/will_factory.cairo", {
            "_will_class_hash": ids.class_hash
        } ).contract_address
    %}

    let (_class_hash) = WillFactory.get_will_class(contract_address=address);
    assert class_hash = _class_hash;

    will_factory_address.write(address);

    return ();
}

@external
func test_deploy_will{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    let (__fp__, _) = get_fp_and_pc();

    let (contract_address) = will_factory_address.read();

    %{ expect_events({"name": "will_creation", "from_address": ids.contract_address}) %}

    // local calldata: (
    //     felt,
    //     felt,
    //     felt,
    //     felt,
    //     UninitializedSplit, UninitializedSplit, UninitializedSplit
    // ) = (
    //     0x1,
    //     2,
    //     2,
    //     2,
    //     0x123,
    //     0x666,
    //     3,
    //     UninitializedSplit(666, 0x12345, 50),
    //     UninitializedSplit(999, 0x54321, 50),
    //     UninitializedSplit(666, 0x98765, 50)
    //     );

    // let (splits: UninitializedSplit*) = alloc();

    // assert splits.beneficiary = 666;
    // assert splits.token = 89;
    // assert splits.percentage = 20;

    // let (pk: felt*) = alloc();

    // assert pk[0] = 1;

    // local governors_tuple: (
    //     felt, felt
    // ) = (1656364407783318604687232152713034315607148126855153562038205511454588619784, 658271760697327575889635688962475244047295624929834779174746028751402329037);

    WillFactory.create_will(
        contract_address=contract_address,
        constructor_calldata_len=16,
        constructor_calldata=cast(new (
        0x1,
        2,
        2,
        2,
        0x123,
        0x666,
        3,
        UninitializedSplit(666, 0x12345, 50),
        UninitializedSplit(999, 0x54321, 50),
        UninitializedSplit(666, 0x98765, 50),
        ), felt*),
    );

    // let (total_splits) = Will.total_splits(contract_address=will_address);
    // let (activation_period) = Will.get_activation_period(contract_address=will_address);

    // let (split_1) = Will.split_of(contract_address=will_address, id=1);
    // let (split_2) = Will.split_of(contract_address=will_address, id=2);
    // let (split_3) = Will.split_of(contract_address=will_address, id=3);

    // let (ids_len, ids) = Will.get_splits_id_of(contract_address=will_address, address=666);

    // assert total_splits = 3;
    // assert activation_period = 86400;

    // assert split_1.beneficiary = 666;
    // assert split_1.token = 0x12345;
    // assert split_1.percentage = 50;
    // assert split_1.expected_amount.low = 0;

    // assert split_2.beneficiary = 999;
    // assert split_2.token = 0x54321;
    // assert split_2.percentage = 50;
    // assert split_2.expected_amount.low = 0;

    // assert split_3.beneficiary = 666;
    // assert split_3.token = 0x98765;
    // assert split_3.percentage = 50;
    // assert split_3.expected_amount.low = 0;

    // assert ids_len = 2;
    // assert ids[0] = 1;
    // assert ids[1] = 3;

    return ();
}
