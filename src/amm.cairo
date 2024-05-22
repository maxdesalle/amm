use starknet::ContractAddress;

#[starknet::interface]
trait IAMM<TContractState> {
    fn getPoolBalance(self: @TContractState, tokenAddress: ContractAddress) -> u128;
    fn getAccountBalance(self: @TContractState, accountAddress: ContractAddress, tokenAddress: ContractAddress) -> u128;
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
		}
}
