module 0x1::HubRegistryTest;

use 0x1::HubRegistry;

/// Helper to create a dummy TxContext for tests
fun create_context(sender: address, epoch: u64): TxContext {
    // Depending on your Move framework or test environment, create or mock a TxContext here.
    // For illustration, assume a helper is available.
    tx_context::mock(sender, epoch)
}

#[test]
public fun test_registry_creation() {
    let ctx = create_context(@0x1, 0);
    let registry = HubRegistry::new_registry(100, 50, &mut ctx);
    assert!(registry.min_tokens_to_propose == 100, 1);
    assert!(registry.min_tokens_to_vote == 50, 2);
    assert!(registry.owner == @0x1, 3);
    assert!(HubRegistry::get_hub_count(&registry) == 0, 4);
}
