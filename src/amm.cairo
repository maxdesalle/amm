use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait IAMM<TContractState> {
    fn get_pool_balance(self: @TContractState, token_address: ContractAddress) -> u128;
    fn get_account_balance(
        self: @TContractState, account_address: ContractAddress, token_address: ContractAddress
    ) -> u128;
    fn create_pool(ref self: TContractState, token_address: ContractAddress, token_amount: u128);
    fn deposit_in_pool(
        ref self: TContractState, token_address: ContractAddress, token_amount: u128
    );
    fn withdraw_from_pool(
        ref self: TContractState, token_address: ContractAddress, token_amount: u128
    );
}

#[starknet::contract]
pub mod AMM {
    use super::IERC20Dispatcher;
    use super::IERC20DispatcherTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;

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
            let allowance = IERC20Dispatcher { contract_address: token_address }
                .allowance(caller, get_contract_address());
            assert(allowance >= token_amount.into(), 'allowance should be >= deposit');
            IERC20Dispatcher { contract_address: token_address }
                .transfer_from(caller, get_contract_address(), token_amount.into());

            self.pool_balance.write(token_address, token_amount);
            self.account_balance.write((caller, token_address), token_amount);
        }

        fn deposit_in_pool(
            ref self: ContractState, token_address: ContractAddress, token_amount: u128
        ) {
            assert(token_amount > 0, 'deposit amount has to be > 0');
            let pool_balance = self.get_pool_balance(token_address);

            if pool_balance == 0 {
                self.create_pool(token_address, token_amount);
            } else {
                let caller: ContractAddress = get_caller_address();
                let allowance = IERC20Dispatcher { contract_address: token_address }
                    .allowance(caller, get_contract_address());
                assert(allowance >= token_amount.into(), 'allowance should be >= deposit');
                IERC20Dispatcher { contract_address: token_address }
                    .transfer_from(caller, get_contract_address(), token_amount.into());
                let account_balance = self.get_account_balance(caller, token_address);
                self.pool_balance.write(token_address, pool_balance + token_amount);
                self.account_balance.write((caller, token_address), account_balance + token_amount);
            }
        }

        fn withdraw_from_pool(
            ref self: ContractState, token_address: ContractAddress, token_amount: u128
        ) {
            let caller: ContractAddress = get_caller_address();
            let account_balance = self.get_account_balance(caller, token_address);
            assert(account_balance >= token_amount, 'cannot withdraw >= balance');
            let pool_balance = self.get_pool_balance(token_address);

            IERC20Dispatcher { contract_address: token_address }
                .transfer(caller, token_amount.into());

            self.pool_balance.write(token_address, pool_balance - token_amount);
            self.account_balance.write((caller, token_address), account_balance - token_amount);
        }
    }
}
