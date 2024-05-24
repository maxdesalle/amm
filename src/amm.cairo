use starknet::ContractAddress;

#[starknet::interface]
pub trait IAMM<TContractState> {
    fn get_pool_balance(self: @TContractState, token_address: ContractAddress) -> u128;
    fn get_account_balance(
        self: @TContractState, account_address: ContractAddress, token_address: ContractAddress
    ) -> u128;
    fn create_pool(ref self: TContractState, token_address: ContractAddress, token_amount: u128);
    fn swap(
        ref self: TContractState,
        input_token_address: ContractAddress,
        input_token_amount: u128,
        output_token_address: ContractAddress
    );
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
        fn get_pool_balance(self: @ContractState, token_address: ContractAddress) -> u128 {
            self.pool_balance.read(token_address)
        }

        fn get_account_balance(
            self: @ContractState, account_address: ContractAddress, token_address: ContractAddress
        ) -> u128 {
            self.account_balance.read((account_address, token_address))
        }

        fn create_pool(
            ref self: ContractState, token_address: ContractAddress, token_amount: u128
        ) {
            assert(token_amount > 0, 'deposit amount has to be > 0');
            assert(self.get_pool_balance(token_address) == 0, 'pool already exists');

            let caller: ContractAddress = get_caller_address();

            self.pool_balance.write(token_address, token_amount);
            self.account_balance.write((caller, token_address), token_amount);
        }

        fn swap(
            ref self: ContractState,
            input_token_address: ContractAddress,
            input_token_amount: u128,
            output_token_address: ContractAddress
        ) {
					assert(self.get_pool_balance(output_token_address) > 0, 'empty output pool');
					}
    }
}
