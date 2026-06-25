import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass/core/providers/core_providers.dart';

void main() {
  // Regression for the "Search failed" bug: openMeteoProvider owns the HTTP
  // client and disposes it on teardown. As an autoDispose provider it was torn
  // down (and the client closed) the instant a listener-less `ref.read` returned
  // — aborting the in-flight place-search request. It must be kept alive, so a
  // read-initiated request can't be cancelled out from under it.
  test('openMeteoProvider is kept alive (same client across reads)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = container.read(openMeteoProvider);
    // Give autoDispose a chance to run if the provider were NOT kept alive.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final second = container.read(openMeteoProvider);

    expect(identical(first, second), isTrue,
        reason: 'a kept-alive client must persist between reads');
  });
}
