use starknet::ContractAddress;
use alexandria_storage::list::{List, ListTrait};

#[starknet::interface]
pub trait IERC20<TContractState> {
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
		fn address_in_owner_list(self: @TContractState, token_address: ContractAddress) -> bool;
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
    fn swap(
        ref self: TContractState,
        input_token_address: ContractAddress,
        input_token_amount: u128,
        output_token_address: ContractAddress
    );
}

#[starknet::contract]
pub mod AMM {
    use super::IERC20Dispatcher;
    use super::IERC20DispatcherTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
		use alexandria_storage::list::{List, ListTrait};

    #[storage]
    pub struct Storage {
        account_balance: LegacyMap::<(ContractAddress, ContractAddress), u128>,
				pool_owners: LegacyMap::<ContractAddress, List<ContractAddress>>,
        pool_balance: LegacyMap::<ContractAddress, u128>
    }

		#[generate_trait]
		impl InternalImpl of InternalTrait {
			fn get_address_index_in_owner_list(ref self: ContractState, token_address: ContractAddress) -> u32 {
				let mut i: u32 = 0;
				let len = self.pool_owners.read(token_address).len();
				let owners = self.pool_owners.read(token_address);

				loop {
					if i == len {
						break;
					}
					if owners[i] == token_address {
						break;
					}
					i += 1;
				};
				return i;
			}

			fn remove_list_element(ref self: ContractState, token_address: ContractAddress, account_address: ContractAddress) {
				let mut i = self.get_address_index_in_owner_list(token_address);
				let mut owners = self.pool_owners.read(token_address);

				if i == owners.len() {
					return;
				}

				if i == 0 {
					owners.pop_front().unwrap();
					return;
				}

				let mut j = i - 1;

				while j >= 0 {
					owners.set(i, owners.get(j).unwrap().unwrap());
					j -= 1;
					i -= 1;
				};

				owners.pop_front().unwrap();
			}
		}

    #[abi(embed_v0)]
    impl AMM of super::IAMM<ContractState> {

				fn address_in_owner_list(self: @ContractState, token_address: ContractAddress) -> bool {
					let mut i = 0;
					let len = self.pool_owners.read(token_address).len();
					let pool_owners = self.pool_owners.read(token_address);

					let result = loop {
						if i == len {
							break false;
						}
						if pool_owners[i] == token_address {
							break true;
						}
						i += 1;
					};
					return result;
				}

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
            let balance = IERC20Dispatcher { contract_address: token_address }.balance_of(caller);
            assert(balance >= token_amount.into(), 'balance should be >= deposit');
            let allowance = IERC20Dispatcher { contract_address: token_address }
                .allowance(caller, caller);
            assert(allowance >= token_amount.into(), 'allowance should be >= deposit');
            IERC20Dispatcher { contract_address: token_address }
                .transfer_from(caller, get_contract_address(), token_amount.into());

            self.pool_balance.write(token_address, token_amount);
						let mut owners = self.pool_owners.read(token_address);
						owners.append(caller).unwrap();
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
                let balance = IERC20Dispatcher { contract_address: token_address }
                    .balance_of(caller);
                assert(balance >= token_amount.into(), 'balance should be >= deposit');
                let allowance = IERC20Dispatcher { contract_address: token_address }
                    .allowance(caller, caller);
                assert(allowance >= token_amount.into(), 'allowance should be >= deposit');
                IERC20Dispatcher { contract_address: token_address }
                    .transfer_from(caller, get_contract_address(), token_amount.into());
                let account_balance = self.get_account_balance(caller, token_address);
                self.pool_balance.write(token_address, pool_balance + token_amount);
								if self.address_in_owner_list(token_address) == false {
									let mut owners = self.pool_owners.read(token_address);
									owners.append(caller).unwrap();
								}
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
						if account_balance - token_amount == 0 {
								self.remove_list_element(token_address, caller);
						}
            self.account_balance.write((caller, token_address), account_balance - token_amount);
        }

        fn swap(
            ref self: ContractState,
            input_token_address: ContractAddress,
            input_token_amount: u128,
            output_token_address: ContractAddress
        ) {
            assert(self.get_pool_balance(output_token_address) > 0, 'empty output pool');

						// let balance = IERC20Dispatcher { contract_address: token_address }
						// 		.balance_of(caller);
						// assert(balance >= token_amount.into(), 'balance should be >= deposit');
						// let allowance = IERC20Dispatcher { contract_address: token_address }
						// 		.allowance(caller, caller);
						// assert(allowance >= token_amount.into(), 'allowance should be >= deposit');
						// IERC20Dispatcher { contract_address: token_address }
						// 		.transfer_from(caller, get_contract_address(), token_amount.into());

						// let input_token_pool_balance = self.get_pool_balance(input_token_address);
						// let output_token_pool_balance = self.get_pool_balance(output_token_address);
						// let output_token_amount = (input_token_amount + output_token_pool_balance) / (input_token_pool_balance + input_token_amount);
						// self.pool_balance.write(input_token_address, input_token_pool_balance + input_token_amount);
						// self.pool_balance.write(output_token_address, output_token_pool_balance - output_token_amount);
        }
    }
}
