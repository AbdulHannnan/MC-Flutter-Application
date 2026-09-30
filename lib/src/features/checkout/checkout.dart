// lib/src/features/checkout — the checkout feature's PUBLIC API (barrel).
//
// Module 14: the pay flow. The checkout screen + Success/Failure screens are
// imported directly by the router (like the other feature screens); other code
// reads only the controller + seams from here.
//
// Seams (all swappable behind their provider):
//   • paymentApiProvider        — mock N-Genius (always approves) → real SDK later.
//   • bookingsApiProvider        — live POST /api/bookings/draft, or a local mock.
//   • notificationsServiceProvider — mock local notifications → real later.
// Orchestration: checkoutControllerProvider ([CheckoutController.pay]).

export 'bookings_api.dart'
    show BookingsApi, Customer, SubmittedBooking, bookingsApiProvider, buildDraftBody;
export 'checkout_controller.dart'
    show CheckoutController, CheckoutOutcome, checkoutControllerProvider;
export 'checkout_validation.dart' show CheckoutErrors, validateCheckout;
export 'notifications.dart'
    show NotificationsService, notificationsServiceProvider;
export 'payment_api.dart' show PaymentApi, PaymentResult, paymentApiProvider;
