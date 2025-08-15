module 0x0::lit_token{

use 0x1::option;
use 0x2::coin::{Self as coin, Coin, TreasuryCap};
use 0x2::transfer;
use 0x2::tx_context::{Self as tx_context, TxContext};
use 0x2::url;

/// Zero-sized type that uniquely identifies your coin.
struct LIT_TOKEN has drop {}

/// Initializes the coin. Runs **once** when you publish.
fun init(witness: LIT_TOKEN, ctx: &mut TxContext) {
   let (treasury, metadata) = coin::create_currency<LIT_TOKEN>(
    witness,
    9, // decimals: u8 (example: 9 decimals)
    b"LYT", // symbol: vector<u8>
    b"Lyt Token", // name: vector<u8>
    b"Example token for Lyt Afrika", // description: vector<u8>
    option::none<url::Url>(), // icon_url: Option<url::Url>
    ctx,
);


    // Freeze metadata so it cannot be modified
    transfer::public_freeze_object(metadata);

    // Mint initial supply to publisher
    let init_amount: u64 = 1_000_000_000;
    let c = coin::mint(&mut treasury, init_amount, ctx);
    transfer::public_transfer(c, tx_context::sender(ctx));

    // Give treasury cap to publisher
    transfer::public_transfer(treasury, tx_context::sender(ctx));
}

/// Mint new tokens to a recipient (TreasuryCap holder only)
public entry fun mint_to(
    treasury: &mut TreasuryCap<LIT_TOKEN>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let c = coin::mint(treasury, amount, ctx);
    transfer::public_transfer(c, recipient);
}

/// Burn tokens
public entry fun burn(
    treasury: &mut TreasuryCap<LIT_TOKEN>,
    coin_to_burn: Coin<LIT_TOKEN>,
) {
    coin::burn(treasury, coin_to_burn);
}

/// Transfer a specific amount (just transfer, do not return Coin)
public entry fun transfer_amount(
    coin: &mut Coin<LIT_TOKEN>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let send = coin::split(coin, amount, ctx);
    transfer::public_transfer(send, recipient);
}

/// Transfer treasury cap to another account
public entry fun transfer_treasury_cap(cap: TreasuryCap<LIT_TOKEN>, new_owner: address) {
    transfer::public_transfer(cap, new_owner);
}
}