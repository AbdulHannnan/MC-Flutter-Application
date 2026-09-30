// Pre-payment revalidation (Module 13): BookingDraftController.revalidate re-checks
// the draft against the live (mock) catalog. Covers the four outcomes — clean OK,
// price drift (auto-applied), and the three blocks (service gone, option gone, slot
// gone). Driven against the real seed service svc_split_clean / opt_split_1 (9900).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/format/date_time.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/booking/availability_providers.dart';
import 'package:microcare/src/features/booking/availability_repository.dart';
import 'package:microcare/src/features/booking/booking_controller.dart';
import 'package:microcare/src/features/booking/booking_revalidation.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/models/models.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

/// A minimal draft service with the given id/option — only the ids and the
/// option price matter to revalidate (it fetches the live service itself).
Service _service(String id) => Service(
      id: id,
      categoryId: 'cat_ac_cleaning',
      name: 'Split AC Deep Cleaning',
      slug: 'split',
      basePrice: _aed(9900),
      duration: 60,
    );

ServiceOption _option(String id, int price) =>
    ServiceOption(id: id, name: 'opt', price: _aed(price), duration: 60);

final _avail = AvailabilityRepository(latency: Duration.zero, demoTaken: false);

TimeSlot _futureSlot() {
  final date = isoDateToString(DateTime.now().add(const Duration(days: 2)));
  return _avail.buildSlots(date).firstWhere((s) => s.isAvailable);
}

TimeSlot _pastSlot() => _avail.buildSlots('2000-01-01').first; // isAvailable == false

void main() {
  late ProviderContainer container;
  BookingDraftController ctrl() => container.read(bookingDraftProvider.notifier);

  setUp(() {
    container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          CatalogRepository(
            ApiClient(baseUrl: 'http://localhost:5050'),
            useMock: true,
            mockLatency: Duration.zero,
          ),
        ),
        availabilityRepositoryProvider.overrideWithValue(_avail),
      ],
    );
    addTearDown(container.dispose);
  });

  test('clean draft revalidates OK', () async {
    ctrl().start(_service('svc_split_clean'), _option('opt_split_1', 9900));
    ctrl().setSlot(_futureSlot());

    final outcome = await ctrl().revalidate();
    expect(outcome.kind, RevalidationKind.ok);
    expect(outcome.canProceed, isTrue);
  });

  test('price drift is auto-applied with an info outcome', () async {
    // Draft holds a stale 5000; the live option is 9900.
    ctrl().start(_service('svc_split_clean'), _option('opt_split_1', 5000));
    ctrl().setSlot(_futureSlot());

    final outcome = await ctrl().revalidate();
    expect(outcome.kind, RevalidationKind.priceUpdated);
    expect(outcome.canProceed, isFalse);
    // The draft's unit price was reconciled to the live value.
    expect(container.read(bookingDraftProvider).unitPrice, _aed(9900));
  });

  test('a removed service blocks', () async {
    ctrl().start(_service('svc_does_not_exist'), _option('opt_x', 9900));
    ctrl().setSlot(_futureSlot());

    final outcome = await ctrl().revalidate();
    expect(outcome.isBlocked, isTrue);
  });

  test('a vanished option blocks', () async {
    ctrl().start(_service('svc_split_clean'), _option('opt_ghost', 9900));
    ctrl().setSlot(_futureSlot());

    final outcome = await ctrl().revalidate();
    expect(outcome.isBlocked, isTrue);
  });

  test('a taken/past slot blocks', () async {
    ctrl().start(_service('svc_split_clean'), _option('opt_split_1', 9900));
    ctrl().setSlot(_pastSlot());

    final outcome = await ctrl().revalidate();
    expect(outcome.isBlocked, isTrue);
  });
}
