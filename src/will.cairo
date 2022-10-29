%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, EcOpBuiltin
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_lt
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem, uint256_mul

from src.ownable import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20
from src.will_governable import WillGovernable, Signature
from src.will_activable import WillActivable, WillStatusEnum

// 7 days
// const DAY_IN_SECONDS = 86400;
// const OWNER_INACTIVITY_PERIOD = 7 * DAY_IN_SECONDS;

@contract_interface
namespace ArgentAccountExtended {
    func getLatestTxTimestamp() -> (timestamp: felt) {
    }
}

struct UninitializedSplit {
    beneficiary: felt,
    token: felt,
    percentage: felt,
}

// `expected_amount` will only be set during the activation process
struct Split {
    beneficiary: felt,
    token: felt,
    percentage: felt,
    expected_amount: Uint256,
}

@storage_var
func _total_splits() -> (res: felt) {
}

@storage_var
func _splits(id: felt) -> (res: Split) {
}

// Keep track of claimed splits to prevent being claimed more than once.
@storage_var
func _is_claimed(id: felt) -> (res: felt) {
}

@storage_var
func _is_valid_(address: felt) -> (res: felt) {
}

//
// EVENTS
//

@event
func activation_start(timestamp: felt) {
}

@event
func activation_rejected(timestamp: felt) {
}

@event
func split_claimed(id: felt) {
}

//
//  CONSTUCTOR
//

// - duration for activation period must be in days (eg 1, 2, 3 days)
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    threshold: felt,
    governors_pk_len: felt,
    governors_pk: felt*,
    splits_len: felt,
    splits: UninitializedSplit*,
) {
    Ownable.set_owner(owner);

    // for demo purposes only,
    // activation period will last only 5seconds
    // after 5sec, splits becomes claimable
    let activation_period_seconds = 5;

    WillActivable.set_activation_period(activation_period_seconds);
    WillGovernable.initialize(threshold, governors_pk_len, governors_pk);

    _total_splits.write(splits_len);
    initialize_splits(0, splits_len, splits);

    return ();
}

@external
func start_activation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}(signatures_len: felt, signatures: Signature*) {
    alloc_locals;
    let (local current_timestamp) = get_block_timestamp();

    // for demo purposes
    with_attr error_message("Will: owner must be inactive for 1min to activate") {
        let (owner) = Ownable.get_owner();
        let (latest_tx_timestamp) = ArgentAccountExtended.getLatestTxTimestamp(
            contract_address=owner
        );

        // true if already past 1mins since the last tx by owner
        assert_lt(latest_tx_timestamp, current_timestamp - (60 * 1));
    }

    WillGovernable.verify_signatures(signatures_len, signatures);
    WillActivable.start_activation();

    let (total_splits) = _total_splits.read();
    calculate_splits_amount(total_splits);

    activation_start.emit(timestamp=current_timestamp);

    return ();
}

@external
func stop_activation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local timestamp) = get_block_timestamp();

    Ownable.only_owner();
    WillActivable.stop_activation();

    activation_rejected.emit(timestamp=timestamp);

    return ();
}

@external
func claim_split{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: felt) {
    alloc_locals;

    with_attr error_message("Will: will is not yet activated") {
        let is_active = WillActivable.is_active();
        assert is_active = TRUE;
    }

    with_attr error_message("Will: split id `{id}` does not exist") {
        let (total) = _total_splits.read();
        assert_not_zero(id);
        assert_le(id, total);
    }

    let (split: Split) = _splits.read(id);

    with_attr error_message("Will: split id `{id}` does not belong to caller") {
        let (caller) = get_caller_address();
        assert caller = split.beneficiary;
    }

    with_attr error_message("Will: split is already claimed") {
        let (is_claimed) = _is_claimed.read(id);
        assert is_claimed = FALSE;
    }

    let (owner) = Ownable.get_owner();

    let (success) = IERC20.transferFrom(
        contract_address=split.token,
        sender=owner,
        recipient=split.beneficiary,
        amount=split.expected_amount,
    );

    _is_claimed.write(id, TRUE);

    split_claimed.emit(id=id);

    return ();
}

//
//  VIEW
//

@view
func get_splits_id_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (res_len: felt, res: felt*) {
    alloc_locals;
    let (local res: felt*) = alloc();

    let (total_splits) = _total_splits.read();
    let (res_len) = get_splits_id_of_address(
        splits_count=0, splits_total=total_splits, address=address, found_len=0, found=res
    );

    return (res_len, res);
}

@view
func split_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: felt) -> (
    res: Split
) {
    let (split) = _splits.read(id);
    return (res=split);
}

@view
func inheritance_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    status: felt
) {
    let (status) = WillActivable.status();
    return (status=status);
}

@view
func total_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    return _total_splits.read();
}

@view
func get_activation_period{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let (timestamp) = WillActivable.get_activation_period();
    return (res=timestamp);
}

@view
func get_all_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    splits_len: felt, splits: Split*
) {
    alloc_locals;

    let (total) = _total_splits.read();
    let (local splits: Split*) = alloc();

    _get_all_splits(0, total, splits);

    return (splits_len=total, splits=splits);
}
//
//  INTERNALS
//

func initialize_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    count: felt, splits_len: felt, splits: UninitializedSplit*
) {
    if (count == splits_len) {
        return ();
    }

    let split: Split = Split(
        beneficiary=splits.beneficiary,
        token=splits.token,
        percentage=splits.percentage,
        expected_amount=Uint256(0, 0),
    );

    _splits.write(count + 1, split);

    initialize_splits(count + 1, splits_len, splits + UninitializedSplit.SIZE);

    return ();
}

func calculate_splits_amount{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}(splits_count: felt) -> () {
    alloc_locals;

    if (splits_count == 0) {
        return ();
    }

    let (owner) = Ownable.get_owner();
    let (local split: Split) = _splits.read(splits_count);

    let (balance: Uint256) = IERC20.balanceOf(contract_address=split.token, account=owner);

    let (nom, _) = uint256_mul(balance, Uint256(split.percentage, 0));
    let (amount, _) = uint256_unsigned_div_rem(nom, Uint256(100, 0));

    let new_split = Split(
        beneficiary=split.beneficiary,
        token=split.token,
        percentage=split.percentage,
        expected_amount=amount,
    );

    _splits.write(splits_count, new_split);

    return calculate_splits_amount(splits_count - 1);
}

func get_splits_id_of_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    splits_count: felt, splits_total: felt, address: felt, found_len: felt, found: felt*
) -> (res_len: felt) {
    alloc_locals;

    if (splits_count == splits_total) {
        return (res_len=found_len);
    }

    let split_id = splits_count + 1;
    let (split) = _splits.read(split_id);

    if (split.beneficiary == address) {
        assert found[found_len] = split_id;
        return get_splits_id_of_address(
            splits_count + 1, splits_total, address, found_len + 1, found
        );
    } else {
        return get_splits_id_of_address(splits_count + 1, splits_total, address, found_len, found);
    }
}

func _get_all_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    splits_count: felt, splits_total: felt, arr: Split*
) {
    if (splits_count == splits_total) {
        return ();
    }

    let (split) = _splits.read(splits_count + 1);

    assert arr.beneficiary = split.beneficiary;
    assert arr.token = split.token;
    assert arr.percentage = split.percentage;
    assert arr.expected_amount = split.expected_amount;

    return _get_all_splits(splits_count + 1, splits_total, arr + Split.SIZE);
}
