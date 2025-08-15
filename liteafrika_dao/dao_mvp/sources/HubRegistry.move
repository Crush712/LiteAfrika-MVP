module 0x0::HubRegistry {

use sui::tx_context::{TxContext, sender};

/// Hub status enum
const PROPOSED: u8 = 0;
const VOTING_OPEN: u8 = 1;
const SELECTED: u8 = 3;

/// Hub object
public struct Hub has key, store {
    id: UID,
    hub_id: u64,
    name: vector<u8>,
    city: vector<u8>,
    latitude: u64,
    longitude: u64,
    contact: vector<u8>,
    proposer: address,
    vote_count: u64,
    status: u8,
    funding_goal: u64,
    funds_raised: u64,
    community_wallet: address,
    voters: vector<address>,
    community_image: vector<u8>,
}

/// Registry object
public struct Registry has key {
    id: UID,
    id_counter: u64,
    hubs: vector<Hub>,
    owner: address,
    min_tokens_to_propose: u64,
    min_tokens_to_vote: u64,
    funding_start: u64,
    funding_end: u64,
}

/// Assert the caller is owner
fun assert_owner(registry: &Registry, ctx: &TxContext) {
    let sender = sui::tx_context::sender(ctx);
    assert!(sender == registry.owner, 401);
}

/// Create a new registry
public entry fun new_registry(
    min_propose: u64,
    min_vote: u64,
    ctx: &mut TxContext
) {
    let registry = Registry {
        id: object::new(ctx),
        id_counter: 0,
        hubs: vector::empty(),
        owner: sender(ctx),
        min_tokens_to_propose: min_propose,
        min_tokens_to_vote: min_vote,
        funding_start: 0,
        funding_end: 0,
    };
    transfer::share_object(registry);
}

/// Propose a new hub
public fun propose_hub(
    registry: &mut Registry,
    name: vector<u8>,
    city: vector<u8>,
    latitude: u64,
    longitude: u64,
    contact: vector<u8>,
    caller_token_balance: u64,
    community_image: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(caller_token_balance >= registry.min_tokens_to_propose, 100);

    let id = registry.id_counter;
    let new_hub = Hub {
        id: sui::object::new(ctx),
        hub_id: id,
        name,
        city,
        latitude,
        longitude,
        contact,
        proposer: sui::tx_context::sender(ctx),
        vote_count: 0,
        status: PROPOSED,
        funding_goal: 0,
        funds_raised: 0,
        community_wallet: @0x0,
        voters: vector::empty(),
        community_image
    };

    vector::push_back(&mut registry.hubs, new_hub);
    registry.id_counter = id + 1;
}

/// Set global voting window (owner only)
public fun set_global_voting_window(
    registry: &mut Registry,
    ctx: &TxContext,
) {
    assert_owner(registry, ctx);

    let len = vector::length(&registry.hubs);
    let mut i = 0;
    while (i < len) {
        let hub_ref = vector::borrow_mut(&mut registry.hubs, i);
        if (hub_ref.status == PROPOSED) {
            hub_ref.status = VOTING_OPEN;
        };
        i = i + 1;
    }
}

/// Vote for a hub (removes timestamp check)
public fun vote_for_hub(
    registry: &mut Registry,
    hub_id: u64,
    caller_token_balance: u64,
    ctx: &mut TxContext,
) {
    assert!(caller_token_balance >= registry.min_tokens_to_vote, 104);
    assert!(hub_id < registry.id_counter, 105);

    let hub_ref = vector::borrow_mut(&mut registry.hubs, hub_id);

    assert!(hub_ref.status == VOTING_OPEN, 106);

    let voter = sui::tx_context::sender(ctx);
    let voters = &hub_ref.voters;
    let mut i = 0;
    while (i < vector::length(voters)) {
        assert!(*vector::borrow(voters, i) != voter, 107);
        i = i + 1;
    };
    vector::push_back(&mut hub_ref.voters, voter);
    hub_ref.vote_count = hub_ref.vote_count + 1;
}

/// Finalize voting (removes timestamp check)
public fun finalize_voting(registry: &mut Registry, ctx: &TxContext): u64 {
    assert_owner(registry, ctx);

    let len = vector::length(&registry.hubs);
    assert!(len > 0, 109);

    let mut highest = 0;
    let mut total_votes = 0;
    let mut votes = vector::empty<u64>();
    let mut i = 0;

    while (i < len) {
        let hub_ref = vector::borrow(&registry.hubs, i);
        let v = hub_ref.vote_count;
        vector::push_back(&mut votes, v);
        total_votes = total_votes + v;
        if (v > highest) {
            highest = v;
        };
        i = i + 1;
    };
    assert!(total_votes > 0, 110);

    let mut tie_count = 0;
    i = 0;
    while (i < len) {
        if (*vector::borrow(&votes, i) == highest) {
            tie_count = tie_count + 1;
        };
        i = i + 1;
    };
    let mut winnerHubId: u64 = 0;

    if (tie_count == 1) {
        i = 0;
        while (i < len) {
            if (*vector::borrow(&votes, i) == highest) {
                winnerHubId = i;
                break
            };
            i = i + 1;
        }
    } else {
        i = 0;
        while (i < len) {
            if (*vector::borrow(&votes, i) == highest) {
                winnerHubId = i;
                break
            };
            i = i + 1;
        }
    };
    let winner_hub_ref = vector::borrow_mut(&mut registry.hubs, winnerHubId);
    winner_hub_ref.status = SELECTED;

    winnerHubId
}

/// Set funding details (owner only)
public fun set_funding_details(
    registry: &mut Registry,
    hub_id: u64,
    funding_goal: u64,
    community_wallet: address,
    ctx: &TxContext,
) {
    assert_owner(registry, ctx);
    assert!(hub_id < registry.id_counter, 111);

    let hub_ref = vector::borrow_mut(&mut registry.hubs, hub_id);

    assert!(hub_ref.funding_goal == 0 && hub_ref.community_wallet == @0x0, 112);
    assert!(funding_goal > 0, 113);
    assert!(community_wallet != @0x0, 114);

    hub_ref.funding_goal = funding_goal;
    hub_ref.community_wallet = community_wallet;
}

/// Fund a selected hub
#[allow(unused_variable)]
public fun fund_hub(registry: &mut Registry, hub_id: u64, amount: u64, ctx: &mut TxContext) {
    assert!(hub_id < registry.id_counter, 201);
    let hub_ref = vector::borrow_mut(&mut registry.hubs, hub_id);
    assert!(hub_ref.status == SELECTED, 202);
    assert!(amount > 0, 203);

    // In a real Sui contract, you would move Coin objects here.
    // For now, we just increment the counter.
    hub_ref.funds_raised = hub_ref.funds_raised + amount;
}

/// Claim funds for the winning hub (community wallet only)
public fun claim_funds(registry: &mut Registry, hub_id: u64, ctx: &mut TxContext) {
    assert!(hub_id < registry.id_counter, 301);
    let hub_ref = vector::borrow_mut(&mut registry.hubs, hub_id);
    let sender = sui::tx_context::sender(ctx);
    assert!(sender == hub_ref.community_wallet, 302);
    assert!(hub_ref.funds_raised >= hub_ref.funding_goal, 303);

    // In a real Sui contract, you would transfer Coin objects here.
    // For now, we just reset funds_raised to 0 to simulate the claim.
    hub_ref.funds_raised = 0;
}

/// Get the number of hubs in the registry
public fun get_hub_count(registry: &Registry): u64 {
    vector::length(&registry.hubs)
}

/// Get a hub by its id (index)
public fun get_hub(registry: &Registry, hub_id: u64): &Hub {
    assert!(hub_id < registry.id_counter, 501);
    vector::borrow(&registry.hubs, hub_id)
}

/// Get the funding goal for a hub
public fun get_funding_goal(registry: &Registry, hub_id: u64): u64 {
    let hub = get_hub(registry, hub_id);
    hub.funding_goal
}

/// Get the funds raised for a hub
public fun get_funds_raised(registry: &Registry, hub_id: u64): u64 {
    let hub = get_hub(registry, hub_id);
    hub.funds_raised
}

/// Get the community wallet address for a hub
public fun get_community_wallet(registry: &Registry, hub_id: u64): address {
    let hub = get_hub(registry, hub_id);
    hub.community_wallet
}

/// Get the status of a hub
public fun get_hub_status(registry: &Registry, hub_id: u64): u8 {
    let hub = get_hub(registry, hub_id);
    hub.status
}

/// Get the vote count for a hub
public fun get_vote_count(registry: &Registry, hub_id: u64): u64 {
    let hub = get_hub(registry, hub_id);
    hub.vote_count
}

/// Get the voters for a hub
public fun get_voters(registry: &Registry, hub_id: u64): &vector<address> {
    let hub = get_hub(registry, hub_id);
    &hub.voters
}
public fun get_community_image(registry: &Registry, hub_id: u64): &vector<u8> {
    let hub = get_hub(registry, hub_id);
    &hub.community_image
}
}