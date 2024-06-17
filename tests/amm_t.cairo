use core::panic_with_felt252;
use amm::amm::{
    IAMM, AMM, IAMMDispatcher, IAMMSafeDispatcher, IAMMDispatcherTrait, IAMMSafeDispatcherTrait,
    IERC20, IERC20Dispatcher, IERC20SafeDispatcher, IERC20DispatcherTrait, IERC20SafeDispatcherTrait
};
use starknet::{ContractAddress, contract_address_const};
use openzeppelin::presets::ERC20Upgradeable;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address
};

fn deploy_amm() -> (ContractAddress, (IAMMDispatcher, IAMMSafeDispatcher)) {
    let contract = declare("AMM").unwrap();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let dispatcher = IAMMDispatcher { contract_address };
    let safe_dispatcher = IAMMSafeDispatcher { contract_address };

    (contract_address, (dispatcher, safe_dispatcher))
}

fn deploy_token(
    name: ByteArray, symbol: ByteArray, initial_supply: u256, recipient: ContractAddress
) -> (ContractAddress, (IERC20Dispatcher, IERC20SafeDispatcher)) {
    let mut calldata = array![];

    name.serialize(ref calldata);
    // calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);
    calldata.append_serde(recipient);

    let contract = declare("ERC20Upgradeable").unwrap();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IERC20Dispatcher { contract_address };
    let safe_dispatcher = IERC20SafeDispatcher { contract_address };

    (contract_address, (dispatcher, safe_dispatcher))
}

#[test]
#[feature("safe_dispatcher")]
fn test_init_pool() {
    let (amm_contract_address, (amm_dispatcher, amm_safe_dispatcher)) = deploy_amm();
    // random account address
    let account_address: ContractAddress = contract_address_const::<
        0x068803fa64609bfa0ebd8b92a8d0c7d91717e2c66f8871582ff9f2e8a1c4b25f
    >();
    let (token_contract_address, (token_dispatcher, _)) = deploy_token(
        "test token", "TEST", 100000000000000000000000000, account_address
    );

    let balance = amm_dispatcher.get_pool_balance(token_contract_address);

    assert(balance == 0, 'balance == 0');
    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 0,
        'balance == 0'
    );

    start_cheat_caller_address(amm_contract_address, account_address);
    start_cheat_caller_address(token_contract_address, account_address);

    token_dispatcher.approve(account_address, 100000000000000000000000000);
    amm_dispatcher.create_pool(token_contract_address, 69420);

    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 69420,
        'balance == 69420'
    );
    assert(amm_dispatcher.get_pool_balance(token_contract_address) == 69420, 'balance == 69420');

    match amm_safe_dispatcher.create_pool(token_contract_address, 0) {
        Result::Ok(_) => panic_with_felt252('should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'deposit amount has to be > 0', *panic_data.at(0));
        }
    }

    let _ = amm_safe_dispatcher.create_pool(token_contract_address, 69420);
    match amm_safe_dispatcher.create_pool(token_contract_address, 42) {
        Result::Ok(_) => panic_with_felt252('should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'pool already exists', *panic_data.at(0));
        }
    }

    stop_cheat_caller_address(token_contract_address);
    stop_cheat_caller_address(amm_contract_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_pool_deposit() {
    let (amm_contract_address, (amm_dispatcher, amm_safe_dispatcher)) = deploy_amm();
    // random account address
    let account_address: ContractAddress = contract_address_const::<
        0x068803fa64609bfa0ebd8b92a8d0c7d91717e2c66f8871582ff9f2e8a1c4b25f
    >();
    let (token_contract_address, (token_dispatcher, _)) = deploy_token(
        "test token", "TEST", 100000000000000000000000000, account_address
    );

    let balance = amm_dispatcher.get_pool_balance(token_contract_address);

    assert(balance == 0, 'balance == 0');
    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 0,
        'balance == 0'
    );

    start_cheat_caller_address(amm_contract_address, account_address);
    start_cheat_caller_address(token_contract_address, account_address);

    token_dispatcher.approve(account_address, 1000000000000000000000000000);
    amm_dispatcher.deposit_in_pool(token_contract_address, 69420);

    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 69420,
        'balance == 69420'
    );
    assert(amm_dispatcher.get_pool_balance(token_contract_address) == 69420, 'balance == 69420');

    match amm_safe_dispatcher.deposit_in_pool(token_contract_address, 0) {
        Result::Ok(_) => panic_with_felt252('should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'deposit amount has to be > 0', *panic_data.at(0));
        }
    }

    match amm_safe_dispatcher.deposit_in_pool(token_contract_address, 100000000000000000000000001) {
        Result::Ok(_) => panic_with_felt252('should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'balance should be >= deposit', *panic_data.at(0));
        }
    }

    stop_cheat_caller_address(token_contract_address);
    stop_cheat_caller_address(amm_contract_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_pool_withdraw() {
    let (amm_contract_address, (amm_dispatcher, amm_safe_dispatcher)) = deploy_amm();
    // random account address
    let account_address: ContractAddress = contract_address_const::<
        0x068803fa64609bfa0ebd8b92a8d0c7d91717e2c66f8871582ff9f2e8a1c4b25f
    >();
    let (token_contract_address, (token_dispatcher, _)) = deploy_token(
        "test token", "TEST", 100000000000000000000000000, account_address
    );

    start_cheat_caller_address(token_contract_address, account_address);
    start_cheat_caller_address(amm_contract_address, account_address);

    token_dispatcher.approve(account_address, 100000000000000000000000000);
    amm_dispatcher.deposit_in_pool(token_contract_address, 69420);

    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 69420,
        'balance == 69420'
    );
    assert(
        token_dispatcher.balance_of(account_address) == 99999999999999999999930580,
        'balance == 9...930580'
    );
    assert(amm_dispatcher.get_pool_balance(token_contract_address) == 69420, 'balance == 69420');

    stop_cheat_caller_address(token_contract_address);
    amm_dispatcher.withdraw_from_pool(token_contract_address, 34710);

    assert(
        token_dispatcher.balance_of(account_address) == 99999999999999999999965290,
        'balance == 9...965290'
    );
    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 34710,
        'balance == 34710'
    );
    assert(amm_dispatcher.get_pool_balance(token_contract_address) == 34710, 'balance == 34710');

    amm_dispatcher.withdraw_from_pool(token_contract_address, 34710);

    assert(token_dispatcher.balance_of(account_address) == 100000000000000000000000000, 'balance == 10...0');
    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 0,
        'balance == 0'
    );
    assert(amm_dispatcher.get_pool_balance(token_contract_address) == 0, 'balance == 0');

    amm_dispatcher.withdraw_from_pool(token_contract_address, 0);
    assert(
        amm_dispatcher.get_account_balance(account_address, token_contract_address) == 0,
        'balance == 0'
    );
    assert(amm_dispatcher.get_pool_balance(token_contract_address) == 0, 'balance == 0');

    match amm_safe_dispatcher.withdraw_from_pool(token_contract_address, 420) {
        Result::Ok(_) => panic_with_felt252('should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'cannot withdraw >= balance', *panic_data.at(0));
        }
    }

    stop_cheat_caller_address(amm_contract_address);
}
