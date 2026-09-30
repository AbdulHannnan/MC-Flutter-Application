// lib/src/features/cart — the cart feature's PUBLIC API (barrel).
//
// Module 13 replaces Module 9's stub (a `cartCountProvider` that always returned
// 0) with the real, locally-persisted cart store. Other features import the cart
// ONLY from here:
//   - the store + mutations (CartController / cartProvider),
//   - the derived reads the UI watches (cartCountProvider for the Home badge,
//     cartSubtotalProvider for the cart/checkout totals).
// The persistence seam (CartStorage) stays private to the feature; the Cart
// screen is imported directly by the router, like the other feature screens.

export 'cart_controller.dart'
    show CartController, cartProvider, cartCountProvider, cartSubtotalProvider;
