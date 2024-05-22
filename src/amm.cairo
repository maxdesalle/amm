#[starknet::contract]
pub mod AMM {

	use starknet::get_caller_address;
	use starknet::ContractAddress;

	#[storage]
    pub struct Storage {
        account_balance: LegacyMap::<(ContractAddress, ContractAddress), u128>,
        pool_balance: LegacyMap::<ContractAddress, u128>
    }

}
