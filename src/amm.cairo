use starknet::ContractAddress;

#[starknet::interface]
trait IAMM<TContractState> {
    fn getPoolBalance(self: @TContractState, tokenAddress: ContractAddress) -> u128;
    fn getAccountBalance(self: @TContractState, accountAddress: ContractAddress, tokenAddress: ContractAddress) -> u128;
		fn createPool(ref self: TContractState, tokenAddress: ContractAddress, tokenAmount: u128);
}

#[starknet::contract]
mod AMM {

	use starknet::ContractAddress;
	use starknet::get_caller_address;

	#[storage]
    struct Storage {
        account_balance: LegacyMap::<(ContractAddress, ContractAddress), u128>,
        pool_balance: LegacyMap::<ContractAddress, u128>
    }

		#[abi(embed_v0)]
		impl AMM of super::IAMM<ContractState> {

			fn getPoolBalance(self: @ContractState, tokenAddress: ContractAddress) -> u128 {
				self.pool_balance.read(tokenAddress)
			}

			fn getAccountBalance(self: @ContractState, accountAddress: ContractAddress, tokenAddress: ContractAddress) -> u128 {
				self.account_balance.read((accountAddress, tokenAddress))
			}

			fn createPool(ref self: ContractState, tokenAddress: ContractAddress, tokenAmount: u128) {
				assert(tokenAmount > 0, 'deposit amount has to be > 0');
				assert(self.getPoolBalance(tokenAddress) == 0, 'pool already exists');

				self.pool_balance.write(tokenAddress, tokenAmount);
			}
		}
}

// fn __setup__() -> felt252 {
//     let class_hash = declare('AMM').unwrap();
//     let prepared = prepare(class_hash, @ArrayTrait::new()).unwrap();
//     let deployed_contract_address = deploy(prepared).unwrap();

//     deployed_contract_address
// }

// #[test]
// fn test_init_pool() {
//     let deployed_contract_address = __setup__();
// 		let tokenAddress: ContractAddress = contract_address_const::<0x06D98dC7ea54CF77eeD141F423f6007Dd61fbd2b6bD429Facdf5d4803353063f>();

//     // check pool balance for TOKEN_TYPE_B was updated
//     let mut calldata = ArrayTrait::new();
//     calldata.append(tokenAddress);
//     let retdata = call(deployed_contract_address, 'get_pool_token_balance', @calldata).unwrap();
//     assert(*retdata.at(0_u32) == 0, 'incorrect pool balance');
// }

