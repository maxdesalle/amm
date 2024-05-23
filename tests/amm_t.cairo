use core::panic_with_felt252;
use amm::amm::{
    IAMM, AMM, IAMMDispatcher, IAMMSafeDispatcher, IAMMDispatcherTrait, IAMMSafeDispatcherTrait
};
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait};

fn deploy_amm() -> (IAMMDispatcher, IAMMSafeDispatcher) {
    let contract = declare("AMM").unwrap();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let dispatcher = IAMMDispatcher { contract_address };
    let safe_dispatcher = IAMMSafeDispatcher { contract_address };

    (dispatcher, safe_dispatcher)
}

#[test]
#[feature("safe_dispatcher")]
fn test_init_pool() {
    let (dispatcher, safe_dispatcher) = deploy_amm();
    let token_address: ContractAddress = contract_address_const::<
        0x06D98dC7ea54CF77eeD141F423f6007Dd61fbd2b6bD429Facdf5d4803353063f
    >();

    let balance = dispatcher.get_pool_balance(token_address);
    assert(balance == 0, 'balance == 0');

    dispatcher.create_pool(token_address, 69420);
    let balance = dispatcher.get_pool_balance(token_address);
    assert(balance == 69420, 'balance == 69420');

    match safe_dispatcher.create_pool(token_address, 0) {
        Result::Ok(_) => panic_with_felt252('should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'deposit amount has to be > 0', *panic_data.at(0));
        }
    }

    let _ = safe_dispatcher.create_pool(token_address, 69420);
    match safe_dispatcher.create_pool(token_address, 42) {
        Result::Ok(_) => panic_with_felt252('should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'pool already exists', *panic_data.at(0));
        }
    }
}
