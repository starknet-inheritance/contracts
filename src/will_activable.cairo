%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp

from src.will_governable import WillGovernable, Signature

struct WillStatusEnum {
    inactive: felt,
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

        WillActivable_status.write(WillStatusEnum.active);
        WillActivable_activated_on.write(current_timestamp);

        return (success=TRUE);
    }

    func stop_activation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        success: felt
    ) {
        with_attr error_message("WillActivable: activation process is not ongoing") {
            let (status) = WillActivable_status.read();
            assert status = WillStatusEnum.active;
        }

        with_attr error_message("WillActivable: already past the activation period") {
            let (current_timestamp) = get_block_timestamp();
            let (activated_on) = WillActivable_activated_on.read();
            let (activation_period) = WillActivable_activation_period.read();

            let window = activated_on + activation_period;

            assert_nn(window - current_timestamp);
        }

        WillActivable_status.write(WillStatusEnum.inactive);
        return (success=TRUE);
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
