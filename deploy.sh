
# This script is used to deploy the icrc1_ledger_canister canister.
TOKEN_SYMBOL="ckETH"
TOKEN_NAME="chain key Ethereum"
TRANSFER_FEE=0
FEATURE_FLAGS=true
DEPLOY_ID="rrkah-fqaaa-aaaaa-aaaaq-cai"
ARCHIVE_CONTROLLER=$(dfx identity get-principal)
TRIGGER_THRESHOLD=2000
NUM_OF_BLOCK_TO_ARCHIVE=1000
CYCLE_FOR_ARCHIVE_CREATION=10000000000000
PRE_MINTED_TOKENS=10000000000
TRANSFER_FEE=10_000
MINTER_ACCOUNT_ID=$(dfx identity get-principal )


dfx deploy cketh --specified-id ss2fx-dyaaa-aaaar-qacoq-cai --argument "(variant {Init = 
record {
     token_symbol = \"${TOKEN_SYMBOL}\";
     token_name = \"${TOKEN_NAME}\";
     minting_account = record { owner = principal \"${MINTER_ACCOUNT_ID}\" };
     transfer_fee = ${TRANSFER_FEE};
     metadata = vec {};
     feature_flags = opt record{icrc2 = ${FEATURE_FLAGS}};
     initial_balances = vec { record { record { owner = principal \"${DEPLOY_ID}\"; }; ${PRE_MINTED_TOKENS}; }; };
     archive_options = record {
         num_blocks_to_archive = ${NUM_OF_BLOCK_TO_ARCHIVE};
         trigger_threshold = ${TRIGGER_THRESHOLD};
         controller_id = principal \"${ARCHIVE_CONTROLLER}\";
         cycles_for_archive_creation = opt ${CYCLE_FOR_ARCHIVE_CREATION};
     };
 }
})"