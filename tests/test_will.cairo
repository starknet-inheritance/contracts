%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_number
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

from src.will import Split
from src.will_governable import Signature
from src.will_activable import WillStatusEnum
from openzeppelin.token.erc20.IERC20 import IERC20

const last_tx = 172800;

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

    func start_activation(signatures_len: felt, signatures: Signature*) {
    }

    func stop_activation() {
    }

    func get_splits_id_of(address: felt) -> (res_len: felt, res: felt*) {
    }

    func get_activation_period() -> (res: felt) {
    }

    func get_all_splits() -> (splits_len: felt, splits: Split*) {
    }
}

@contract_interface
namespace Account {
    func getLatestTxTimestamp() -> (timestamp: felt) {
    }
}

@storage_var
func will_contract_address() -> (res: felt) {
}

@storage_var
func token1() -> (res: felt) {
}

@storage_var
func token2() -> (res: felt) {
}

@storage_var
func will_owner() -> (res: felt) {
}

func __deploy_mock_erc20s__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local _token1;
    local _token2;

    let (owner) = will_owner.read();

    %{
        ids._token1 = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo",
            {
                "name" :"Ether",
                "symbol" : "ETH",
                "decimals" : 18,
                "initial_supply": {
                    "low" : 1000000000,
                    "high" : 0
                },
                "recipient" : ids.owner
            }
        ).contract_address;

        ids._token2 = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo",
            {
                "name" :"Dai",
                "symbol" : "DAI",
                "decimals" : 18,
                "initial_supply": {
                    "low" : 1000000000,
                    "high" : 0
                },
                "recipient" : ids.owner
            }
        ).contract_address;
    %}

    token1.write(_token1);
    token2.write(_token2);

    return ();
}

func __deploy_account__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    tempvar account;

    %{
        ids.account = deploy_contract("src/account/argent_account_extended.cairo").contract_address
        store(ids.account, "latest_tx_timestamp", [ids.last_tx])
    %}

    let (timestamp) = Account.getLatestTxTimestamp(contract_address=account);

    assert timestamp = last_tx;

    return (address=account);
}

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    let (owner) = __deploy_account__();
    will_owner.write(owner);

    __deploy_mock_erc20s__();

    local will_address;

    let (_token1) = token1.read();
    let (_token2) = token2.read();

    %{
        ids.will_address = deploy_contract(
            "src/will.cairo",
            {
                "owner": ids.owner,
                "splits" : [
                    {   
                        "beneficiary" :666, 
                        "token": ids._token1, 
                        "percentage": 50,                        
                    },
                    {
                        "beneficiary" : 999, 
                        "token": ids._token1, 
                        "percentage": 50,                        
                    },
                    {
                        "beneficiary" : 666, 
                        "token": ids._token2, 
                        "percentage": 50,                        
                    }
                ],
                "threshold": 2,
                "governors_pk": [1656364407783318604687232152713034315607148126855153562038205511454588619784, 658271760697327575889635688962475244047295624929834779174746028751402329037]
            } 
        ).contract_address
    %}

    %{
        stop_prank1 = start_prank(ids.owner, ids._token1)
        stop_prank2 = start_prank(ids.owner, ids._token2)
    %}

    IERC20.approve(contract_address=_token1, spender=will_address, amount=Uint256(0, 100000000));
    IERC20.approve(contract_address=_token2, spender=will_address, amount=Uint256(0, 100000000));

    %{
        stop_prank1()
        stop_prank2()
    %}

    will_contract_address.write(will_address);

    return ();
}

@external
func test_initialize_will{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    let (owner) = will_owner.read();
    let (will_address) = will_contract_address.read();
    let (_token1) = token1.read();
    let (_token2) = token2.read();

    let (total_splits) = Will.total_splits(contract_address=will_address);
    let (activation_period) = Will.get_activation_period(contract_address=will_address);

    let (split_1) = Will.split_of(contract_address=will_address, id=1);
    let (split_2) = Will.split_of(contract_address=will_address, id=2);
    let (split_3) = Will.split_of(contract_address=will_address, id=3);

    let (ids_len, ids) = Will.get_splits_id_of(contract_address=will_address, address=666);

    let (allowance1: Uint256) = IERC20.allowance(
        contract_address=_token1, owner=owner, spender=will_address
    );
    let (allowance2: Uint256) = IERC20.allowance(
        contract_address=_token2, owner=owner, spender=will_address
    );

    assert total_splits = 3;
    assert activation_period = 5;

    assert split_1.beneficiary = 666;
    assert split_1.token = _token1;
    assert split_1.percentage = 50;
    assert split_1.expected_amount.low = 0;

    assert split_2.beneficiary = 999;
    assert split_2.token = _token1;
    assert split_2.percentage = 50;
    assert split_2.expected_amount.low = 0;

    assert split_3.beneficiary = 666;
    assert split_3.token = _token2;
    assert split_3.percentage = 50;
    assert split_3.expected_amount.low = 0;

    assert ids_len = 2;
    assert ids[0] = 1;
    assert ids[1] = 3;

    assert allowance1.high = 100000000;
    assert allowance2.high = 100000000;

    let (splits_len, splits: Split*) = Will.get_all_splits(contract_address=will_address);

    assert split_1.beneficiary = splits[0].beneficiary;
    assert split_1.token = splits[0].token;
    assert split_1.percentage = splits[0].percentage;
    assert split_1.expected_amount.low = splits[0].expected_amount.low;

    assert split_2.beneficiary = splits[1].beneficiary;
    assert split_2.token = splits[1].token;
    assert split_2.percentage = splits[1].percentage;
    assert split_2.expected_amount.low = splits[1].expected_amount.low;

    assert split_3.beneficiary = splits[2].beneficiary;
    assert split_3.token = splits[2].token;
    assert split_3.percentage = splits[2].percentage;
    assert split_3.expected_amount.low = splits[2].expected_amount.low;

    assert splits_len = total_splits;

    return ();
}

@external
func test_start_activation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;

    let (contract_address) = will_contract_address.read();
    let (sign: Signature*) = alloc();

    assert sign[0] = Signature(0x2b94ea0156794006a62fe1bda19e6c32083499d8d13c3a605abc1a5288d6dfe, 0x37116782c568c5cc7a5da13425395a8a17c0ca6babd0b3970637bb7c1113a9f);
    assert sign[1] = Signature(0x64df89530d2cb4a2377c6cff689da1dd54b72d325be44a3ef814f179aa34bde, 0x4c3deeae07ad308b84722340e9878460350c12b517c0087953ae8fe7bfcf6d5);

    // 1min + 1sec after owner's last transaction time
    let new_time = last_tx + (60 * 1 + 1);

    %{
        stop_warp = warp(ids.new_time, ids.contract_address) 
        expect_events({"name": "activation_start" , "from_address": ids.contract_address})
    %}

    Will.start_activation(contract_address=contract_address, signatures_len=2, signatures=sign);

    %{ stop_warp() %}

    let (status) = Will.inheritance_status(contract_address);

    assert status = WillStatusEnum.pending;

    return ();
}

@external
func test_fail_start_activation_owner_not_inactive{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;

    let (contract_address) = will_contract_address.read();
    let (sign: Signature*) = alloc();

    assert sign[0] = Signature(0x2b94ea0156794006a62fe1bda19e6c32083499d8d13c3a605abc1a5288d6dfe, 0x37116782c568c5cc7a5da13425395a8a17c0ca6babd0b3970637bb7c1113a9f);
    assert sign[1] = Signature(0x64df89530d2cb4a2377c6cff689da1dd54b72d325be44a3ef814f179aa34bde, 0x4c3deeae07ad308b84722340e9878460350c12b517c0087953ae8fe7bfcf6d5);

    // 30secs after owner's last tx happened
    let new_time = last_tx + (30);

    %{
        stop_warp = warp(ids.new_time, ids.contract_address) 
        expect_revert(error_message="Will: owner must be inactive for 1min to activate")
    %}

    Will.start_activation(contract_address=contract_address, signatures_len=2, signatures=sign);

    %{ stop_warp() %}

    let (status) = Will.inheritance_status(contract_address);

    assert status = WillStatusEnum.pending;

    return ();
}

// not enough signatures == no. of valid sigs < threshold
@external
func test_fail_start_activation_not_enough_signatures{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;

    let (contract_address) = will_contract_address.read();
    let (sign: Signature*) = alloc();

    assert sign[0] = Signature(0x2b94ea0156794006a62fe1bda19e6c32083499d8d13c3a605abc1a5288d6dfe, 0x37116782c568c5cc7a5da13425395a8a17c0ca6babd0b3970637bb7c1113a9f);

    // 7 day (+ 1 second) after owner's last transaction time
    let new_time = last_tx + (86400 * 7 + 1);

    %{
        stop_warp = warp(ids.new_time, ids.contract_address) 
        expect_revert(error_message="WillGovernable: not enough valid signatures")
    %}

    Will.start_activation(contract_address=contract_address, signatures_len=1, signatures=sign);

    %{ stop_warp() %}

    return ();
}

@external
func test_stop_activation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;

    let (local contract_address) = will_contract_address.read();
    let (local owner) = will_owner.read();

    test_start_activation();

    %{
        stop_prank = start_prank(ids.owner, ids.contract_address)
        expect_events({"name": "activation_rejected" , "from_address": ids.contract_address})
    %}

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
    alloc_locals;

    let (local contract_address) = will_contract_address.read();
    let (local owner) = will_owner.read();

    test_start_activation();

    %{
        stop_prank = start_prank(ids.owner, ids.contract_address)
        stop_warp = warp(123456789 + (86400 + 1), ids.contract_address)

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
func test_claim_split{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;
    let (local contract_address) = will_contract_address.read();

    test_start_activation();

    let (local period) = Will.get_activation_period(contract_address=contract_address);

    let new_time = last_tx + (86400 * 7 + 1) + (period + 1);

    let (_token1) = token1.read();
    let (owner) = will_owner.read();
    let (owner_balance_before) = IERC20.balanceOf(contract_address=_token1, account=owner);

    %{
        stop_prank_1 = start_prank(666, ids.contract_address)
        stop_warp = warp(ids.new_time + 1, ids.contract_address)
        expect_events({"name": "split_claimed" , "data": [1], "from_address": ids.contract_address})
    %}

    Will.claim_split(contract_address=contract_address, id=1);

    %{
        stop_prank_1()
        stop_prank_2 = start_prank(999, ids.contract_address)
    %}

    Will.claim_split(contract_address=contract_address, id=2);

    let (owner_balance_after) = IERC20.balanceOf(contract_address=_token1, account=owner);
    let (claimer_balance) = IERC20.balanceOf(contract_address=_token1, account=666);

    %{
        print(f"claimer balance : {ids.claimer_balance.low}")
        print(f"balance owner before : {ids.owner_balance_before.low}")
        print(f"balance owner after : {ids.owner_balance_after.low}")

        stop_prank_2()
        stop_warp()
    %}

    return ();
}

@external
func test_fail_claim_split_when_will_inactive{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;
    let (local contract_address) = will_contract_address.read();
    let (local period) = Will.get_activation_period(contract_address=contract_address);

    test_start_activation();

    let new_time = last_tx + (86400 * 7 + 1) + (period - 1);

    %{
        stop_prank = start_prank(666, ids.contract_address)
        stop_warp = warp(ids.new_time - 100, ids.contract_address)

        expect_revert(error_message="Will: will is not yet activated")
    %}

    Will.claim_split(contract_address=contract_address, id=1);

    %{
        stop_prank()
        stop_warp()
    %}

    return ();
}

@external
func test_fail_claim_already_claimed_split{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;
    let (local contract_address) = will_contract_address.read();

    test_claim_split();

    %{
        stop_prank = start_prank(666, ids.contract_address)
        stop_warp = warp(123456789 + (86400 + 1), ids.contract_address)

        expect_revert(error_message="Will: split is already claimed")
    %}

    Will.claim_split(contract_address=contract_address, id=1);

    %{
        stop_prank()
        stop_warp()
    %}

    return ();
}
