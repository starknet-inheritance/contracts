%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func Ownable_owner() -> (address: felt) {
}

namespace Ownable {
    func only_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        with_attr error_message("Ownable: only owner is allowed") {
            let (caller) = get_caller_address();
            let (owner) = Ownable_owner.read();
            assert caller = owner;
        }
        return ();
    }

    func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        address: felt
    ) {
        return Ownable_owner.read();
    }

    func set_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) {
        Ownable_owner.write(address);
        return ();
    }
}
