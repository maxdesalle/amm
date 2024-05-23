use starknet::ContractAddress;

#[starknet::interface]
pub trait IAMM<TContractState> {
    fn getPoolBalance(self: @TContractState, tokenAddress: ContractAddress) -> u128;
    fn getAccountBalance(
        self: @TContractState, accountAddress: ContractAddress, tokenAddress: ContractAddress
    ) -> u128;
    fn createPool(ref self: TContractState, tokenAddress: ContractAddress, tokenAmount: u128);
}

#[starknet::contract]
pub mod AMM {
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    pub struct Storage {
        account_balance: LegacyMap::<(ContractAddress, ContractAddress), u128>,
        pool_balance: LegacyMap::<ContractAddress, u128>
    }

    #[abi(embed_v0)]
    impl AMM of super::IAMM<ContractState> {
        fn getPoolBalance(self: @ContractState, tokenAddress: ContractAddress) -> u128 {
            self.pool_balance.read(tokenAddress)
        }

        fn getAccountBalance(
            self: @ContractState, accountAddress: ContractAddress, tokenAddress: ContractAddress
        ) -> u128 {
            self.account_balance.read((accountAddress, tokenAddress))
        }

        fn createPool(ref self: ContractState, tokenAddress: ContractAddress, tokenAmount: u128) {
            assert(tokenAmount > 0, 'deposit amount has to be > 0');
            assert(self.getPoolBalance(tokenAddress) == 0, 'pool already exists');

            self.pool_balance.write(tokenAddress, tokenAmount);
        }
    }
}
