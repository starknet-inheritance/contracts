%lang starknet

from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp

from src.will_governable import WillGovernable, Signature

struct WillStatusEnum {
    inactive: felt,
    pending: felt,
    active: felt,
}

@storage_var
func WillActivable_status() -> (res: felt) {
}

@storage_var
func WillActivable_activation_period() -> (res: felt) {
}

@storage_var
func WillActivable_activated_on() -> (res: felt) {
}

namespace WillActivable {
    func start_activation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        success: felt
    ) {
        with_attr error_message("WillActivable: activation process is already ongoing") {
            let (status) = WillActivable_status.read();
            assert status = WillStatusEnum.inactive;
        }

        let (current_timestamp) = get_block_timestamp();

        WillActivable_status.write(WillStatusEnum.pending);
        WillActivable_activated_on.write(current_timestamp);

        return (success=TRUE);
    }

    func stop_activation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        success: felt
    ) {
        with_attr error_message("WillActivable: activation process is not ongoing") {
            let (status) = WillActivable_status.read();
            assert status = WillStatusEnum.pending;
        }

        with_attr error_message("WillActivable: already past the activation period") {
            let (limit) = calculate_activation_period_limit();
            let (current_timestamp) = get_block_timestamp();
            assert_nn(limit - current_timestamp);
        }

        WillActivable_activated_on.write(0);
        WillActivable_status.write(WillStatusEnum.inactive);
        return (success=TRUE);
    }

    func is_active{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
        alloc_locals;
        let (status) = WillActivable_status.read();

        if (status == WillStatusEnum.inactive) {
            return FALSE;
        }

        let (limit) = calculate_activation_period_limit();

        let (current_timestamp) = get_block_timestamp();
        let res = is_nn(current_timestamp - limit);

        return res;
    }

    func set_activation_period{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        duration: felt
    ) {
        WillActivable_activation_period.write(duration);
        return ();
    }

    func get_activation_period{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (duration: felt) {
        let (duration) = WillActivable_activation_period.read();
        return (duration=duration);
    }

    func status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
        return WillActivable_status.read();
    }
}

func calculate_activation_period_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() -> (res: felt) {
    let (activated_on) = WillActivable_activated_on.read();
    let (activation_period) = WillActivable_activation_period.read();
    let limit = activated_on + activation_period;
    return (res=limit);
}
