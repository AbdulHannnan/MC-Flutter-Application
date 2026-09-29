// The booking DRAFT store (Module 11): the Riverpod port of RN's useBookingStore.
// Covers the mutations (start/setOption/toggleAddon/setAddons/set*/reset), the
// derived reads (unitPrice / subtotal / duration / normalizedNotes), the
// pre-checkout applyLiveUnitPrice, and buildCartItem.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/booking/booking.dart';
import 'package:microcare/src/models/models.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

final _option1 =
    ServiceOption(id: 'o1', name: '1 unit', price: _aed(9900), duration: 60);
final _option2 =
    ServiceOption(id: 'o2', name: '2 units', price: _aed(17900), duration: 90);
final _addon1 = ServiceAddon(
    id: 'a1', name: 'Deep clean', price: _aed(1000), duration: 15);
final _addon2 = ServiceAddon(id: 'a2', name: 'Gas top-up', price: _aed(2000));

final _service = Service(
  id: 's1',
  categoryId: 'c1',
  name: 'Split AC Deep Cleaning',
  slug: 'split-clean',
  basePrice: _aed(5000),
  duration: 30,
  options: [_option1, _option2],
  addons: [_addon1, _addon2],
);

void main() {
  late ProviderContainer container;
  BookingDraftController ctrl() => container.read(bookingDraftProvider.notifier);
  BookingDraft draft() => container.read(bookingDraftProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts empty', () {
    final d = draft();
    expect(d.hasService, isFalse);
    expect(d.service, isNull);
    expect(d.addons, isEmpty);
    expect(d.unitPrice, isNull);
    expect(d.subtotal, isNull);
    expect(d.buildCartItem(), isNull);
  });

  test('start sets service + option and clears the rest', () {
    ctrl()
      ..setNotes('stale')
      ..start(_service, _option1);
    final d = draft();
    expect(d.service?.id, 's1');
    expect(d.option?.id, 'o1');
    expect(d.addons, isEmpty);
    expect(d.location, isNull);
    expect(d.slot, isNull);
    expect(d.notes, isEmpty); // cleared by start
  });

  test('unitPrice is the option price, else the service base', () {
    ctrl().start(_service, _option1);
    expect(draft().unitPrice, _aed(9900));

    ctrl().setOption(null);
    expect(draft().unitPrice, _aed(5000)); // falls back to base
  });

  test('subtotal and duration include ticked add-ons', () {
    ctrl().start(_service, _option1);
    expect(draft().subtotal, _aed(9900));
    expect(draft().duration, 60);

    ctrl().toggleAddon(_addon1); // +10.00, +15 min
    expect(draft().subtotal, _aed(10900));
    expect(draft().duration, 75);

    ctrl().setAddons([_addon1, _addon2]); // +10.00 +20.00 (no extra minutes)
    expect(draft().subtotal, _aed(12900));
    expect(draft().duration, 75);
  });

  test('toggleAddon adds then removes by id', () {
    ctrl()
      ..start(_service, _option1)
      ..toggleAddon(_addon1);
    expect(draft().addons.map((a) => a.id), ['a1']);

    ctrl().toggleAddon(_addon1);
    expect(draft().addons, isEmpty);
  });

  test('setLocation / setSlot / setNotes keep the rest of the draft', () {
    ctrl().start(_service, _option1);
    const loc = BookingLocation(addressText: 'Marina', area: 'Dubai Marina');
    const slot = TimeSlot(id: 't1', start: '2026-10-01T09:00:00', end: '2026-10-01T10:00:00');

    ctrl()
      ..setLocation(loc)
      ..setSlot(slot)
      ..setNotes('gate code 1234');
    final d = draft();
    expect(d.service?.id, 's1');
    expect(d.option?.id, 'o1');
    expect(d.location, loc);
    expect(d.slot?.id, 't1');
    expect(d.notes, 'gate code 1234');
  });

  test('normalizedNotes blanks to null', () {
    ctrl()
      ..start(_service, _option1)
      ..setNotes('   ');
    expect(draft().normalizedNotes, isNull);

    ctrl().setNotes('hello');
    expect(draft().normalizedNotes, 'hello');
  });

  test('applyLiveUnitPrice updates the option price, or the base with no option',
      () {
    ctrl().start(_service, _option1);
    ctrl().applyLiveUnitPrice(_aed(8800));
    expect(draft().option?.price, _aed(8800));
    expect(draft().unitPrice, _aed(8800));

    ctrl().setOption(null);
    ctrl().applyLiveUnitPrice(_aed(4200));
    expect(draft().service?.basePrice, _aed(4200));
    expect(draft().unitPrice, _aed(4200));
  });

  test('buildCartItem snapshots the configured booking', () {
    ctrl()
      ..start(_service, _option2)
      ..setAddons([_addon1])
      ..setNotes('ring the bell');
    final item = draft().buildCartItem()!;

    expect(item.serviceId, 's1');
    expect(item.optionId, 'o2');
    expect(item.quantity, 1);
    expect(item.serviceName, 'Split AC Deep Cleaning');
    expect(item.optionName, '2 units');
    expect(item.unitPrice, _aed(17900));
    expect(item.addons.map((a) => a.id), ['a1']);
    expect(item.addons.first, isA<CartAddon>());
    expect(item.notes, 'ring the bell');
    expect(item.id, startsWith('s1__')); // makeLineId shape
  });

  test('reset clears the draft', () {
    ctrl()
      ..start(_service, _option1)
      ..toggleAddon(_addon1)
      ..reset();
    expect(draft().hasService, isFalse);
    expect(draft().addons, isEmpty);
  });
}
