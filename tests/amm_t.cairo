use amm::amm::{IAMM, AMM, IAMMDispatcher, IAMMDispatcherTrait};
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait};

fn deploy_amm() -> (IAMMDispatcher, ContractAddress) {
    let contract = declare("AMM").unwrap();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let dispatcher = IAMMDispatcher { contract_address };

    (dispatcher, contract_address)
}

#[test]
fn test_init_pool() {
    let (dispatcher, _) = deploy_amm();
    let tokenAddress: ContractAddress = contract_address_const::<
        0x06D98dC7ea54CF77eeD141F423f6007Dd61fbd2b6bD429Facdf5d4803353063f
    >();

    let balance = dispatcher.getPoolBalance(tokenAddress);
    assert(balance == 0, 'balance == 0');
}
