%lang starknet

from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.cairo_builtins import HashBuiltin, EcOpBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.token.erc20.IERC20 import IERC20
from src.ownable import Ownable
from src.will_governable import WillGovernable, Signature

struct InheritanceStatusEnum {
    inactive: felt,
    pending: felt,
    active: felt,
}

struct Split {
    beneficiary: felt,
    token: felt,
    percentage: felt,
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

@storage_var
func _inheritance_status() -> (res: felt) {
}

//
//  CONSTUCTOR
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    splits_len: felt,
    splits: Split*,
    threshold: felt,
    governors_pk_len: felt,
    governors_pk: felt*,
) {
    Ownable.set_owner(owner);
    WillGovernable.initialize(threshold, governors_pk_len, governors_pk);

    _total_splits.write(splits_len);
    _initialize_splits(splits_len, splits);

    return ();
}

func _initialize_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    splits_len: felt, splits: Split*
) {
    if (splits_len == 0) {
        return ();
    }

    let split: Split = Split(
        beneficiary=splits.beneficiary, token=splits.token, amount=splits.amount
    );

    _splits.write(splits_len, split);

    _initialize_splits(splits_len - 1, splits + Split.SIZE);

    return ();
}

//
//  EXTERNALS
//

@external
func start_activation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ec_op_ptr: EcOpBuiltin*
}(signatures_len: felt, signatures: Signature*) {
    WillGovernable.verify_signatures(signatures_len, signatures);
    _inheritance_status.write(InheritanceStatusEnum.pending);
    return ();
}

// - This function should allow caller to claim all splits that satisfies `caller == split.beneficiary`
// - Should initiate token transfer directly to beneficiary address
@external
func claim_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    let (caller) = get_caller_address();
    let (total) = _total_splits.read();
    let (owner) = Ownable.get_owner();

    let (total_claimed) = _claim_splits_loop(
        total_claimed=0,
        split_count=total,
        caller=caller,
        owner=owner
    );

    return ();
}

func _claim_splits_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(total_claimed: felt, split_count: felt, caller: felt, owner: felt) -> (total_claimed: felt) {
    if (total_splits == 0) {
        return (total_claimed=total_claimed);
    }

    let (split: Split*) = _splits.read(split_count);

    if (split.beneficiary == recipient) {
        // 1. query owner's token balance
        // 2. calculate amount based on split percentage
        // 3. transfer amount to beneficiary 
        
        let (balance) = IERC20.balanceOf(
            contract_address=split.token,
            account=owner
        );
        
        // issue : next split of the same token will calculate its percentage 
        // based on `balance - amount`, which will result in wrong amount (less that expected).
        // 
        // as of now, the div remainder `r` should just be ignored to make things easier 
        //
        let nom = balance * split.percentage;
        let (amount, r) = unsigned_div_rem(nom, 100);

        let (success) = IERC20.transferFrom(
            contract_address=split.token,
            sender=owner,
            recipient=split.beneficiary,
            amount=amount
        );

        return _claim_splits_loop(
            total_claimed=total_claimed + 1,
            split_count=split_count - 1,
            caller=caller,
            owner=owner
        );
    } else {
        return _claim_splits_loop(
            total_claimed=total_claimed,
            split_count=split_count - 1,
            caller=caller,
            owner=owner
        );
    }
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

@view
func split_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: felt) -> (
    res: Split
) {
    let (split) = _splits.read(id);
    return (res=split);
}

@view
func inheritance_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    return _inheritance_status.read();
}

@view
func total_splits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    return _total_splits.read();
}
