%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin, EcOpBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem, uint256_mul

from src.ownable import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20
from src.will_governable import WillGovernable, Signature
from src.will_activable import WillActivable, WillStatusEnum

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
//  CONSTUCTOR
//

// - duration for activation period must be in seconds e.g. 1 day = 86400 seconds
// activation period will later be calculated as `current block timestamp + duration)
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    activation_period: felt,
    splits_len: felt,
    splits: UninitializedSplit*,
    threshold: felt,
    governors_pk_len: felt,
    governors_pk: felt*,
) {
    Ownable.set_owner(owner);

    WillActivable.set_activation_period(activation_period);
    WillGovernable.initialize(threshold, governors_pk_len, governors_pk);

    _total_splits.write(splits_len);
    initialize_splits(0, splits_len, splits);

    return ();
}

//
//  EXTERNALS
//

//
// TODO: check owner's account contract activity status
//

@external
func start_activation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}(signatures_len: felt, signatures: Signature*) {
    WillGovernable.verify_signatures(signatures_len, signatures);
    WillActivable.start_activation();

    let (total_splits) = _total_splits.read();
    calculate_splits_amount(total_splits);

    return ();
}

@external
func stop_activation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.only_owner();
    WillActivable.stop_activation();
    return ();
}

// - This function should allow caller to claim all splits that satisfies `caller == split.beneficiary`
// - Should initiate token transfer directly to beneficiary address
@external
func claim_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    total_claimed: felt
) {
    alloc_locals;

    with_attr error_message("Will: cannot claim because will is not activated yet") {
        let (status) = WillActivable.status();
        assert status = WillStatusEnum.active;
    }

    let (owner) = Ownable.get_owner();
    let (total) = _total_splits.read();
    let (caller) = get_caller_address();

    let (total_claimed) = _claim_splits_loop(
        total_claimed=0, split_count=total, caller=caller, owner=owner
    );

    return (total_claimed=total_claimed);
}

//
//  VIEW
//

@view
func count_splits_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (res: felt) {
    let (total_splits) = _total_splits.read();
    let count = _count_splits_loop(total_splits, address, 0);
    return (res=count);
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

    // issue : next split of the same token will calculate its percentage
    // based on `balance - amount`, which will result in wrong amount (less that expected).
    //
    // as of now, the div remainder should just be ignored to make things easier
    //
    // amount == balance * (split.percentage/100) == (balance * split.percentage) / 100
    //
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

func _claim_splits_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    total_claimed: felt, split_count: felt, caller: felt, owner: felt
) -> (total_claimed: felt) {
    alloc_locals;

    if (split_count == 0) {
        return (total_claimed=total_claimed);
    }

    let (local split: Split) = _splits.read(split_count);

    if (split.beneficiary == caller) {
        let (success) = IERC20.transferFrom(
            contract_address=split.token,
            sender=owner,
            recipient=split.beneficiary,
            amount=split.expected_amount,
        );

        return _claim_splits_loop(
            total_claimed=total_claimed + 1, split_count=split_count - 1, caller=caller, owner=owner
        );
    } else {
        return _claim_splits_loop(
            total_claimed=total_claimed, split_count=split_count - 1, caller=caller, owner=owner
        );
    }
}

func _count_splits_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    splits_count: felt, address: felt, total_found: felt
) -> felt {
    alloc_locals;

    if (splits_count == 0) {
        return total_found;
    }

    let (splits) = _splits.read(splits_count);

    if (splits.beneficiary == address) {
        return _count_splits_loop(splits_count - 1, address, total_found + 1);
    } else {
        return _count_splits_loop(splits_count - 1, address, total_found);
    }
}
