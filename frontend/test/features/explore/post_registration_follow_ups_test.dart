import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/explore/application/post_registration_follow_ups.dart';

void main() {
  group('Post-registration follow-ups', () {
    test('empty Wishlist does not prevent Trip suggestions', () async {
      final operations = <String>[];

      final result = await runPostRegistrationFollowUps(
        registrationSucceeded: true,
        shouldSuggestTrips: true,
        handleWishlist: () async {
          operations.add('wishlist');

          // No matching Wishlist entry.
          // The follow-up finishes without presenting anything.
          return;
        },
        handleTripSuggestions: () async {
          operations.add('trip-suggestions');
        },
      );

      expect(result, isTrue);

      expect(operations, ['wishlist', 'trip-suggestions']);
    });

    test(
      'does not request suggestions when a Trip was already selected',
      () async {
        var wishlistCalls = 0;
        var suggestionCalls = 0;

        final result = await runPostRegistrationFollowUps(
          registrationSucceeded: true,
          shouldSuggestTrips: false,
          handleWishlist: () async {
            wishlistCalls++;
          },
          handleTripSuggestions: () async {
            suggestionCalls++;
          },
        );

        expect(result, isTrue);

        expect(wishlistCalls, 1);
        expect(suggestionCalls, 0);
      },
    );

    test('Trip suggestion failure does not invalidate saved visit', () async {
      var wishlistCalls = 0;
      var suggestionCalls = 0;

      final result = await runPostRegistrationFollowUps(
        registrationSucceeded: true,
        shouldSuggestTrips: true,
        handleWishlist: () async {
          wishlistCalls++;
        },
        handleTripSuggestions: () async {
          suggestionCalls++;

          throw Exception('Unable to load Trips');
        },
      );

      expect(result, isTrue);

      expect(wishlistCalls, 1);
      expect(suggestionCalls, 1);
    });

    test('Wishlist failure does not prevent Trip suggestions', () async {
      final operations = <String>[];

      final result = await runPostRegistrationFollowUps(
        registrationSucceeded: true,
        shouldSuggestTrips: true,
        handleWishlist: () async {
          operations.add('wishlist');

          throw Exception('Unable to refresh Wishlist');
        },
        handleTripSuggestions: () async {
          operations.add('trip-suggestions');
        },
      );

      expect(result, isTrue);

      expect(operations, ['wishlist', 'trip-suggestions']);
    });

    test('failed registration never starts follow-ups', () async {
      var wishlistCalls = 0;
      var suggestionCalls = 0;

      final result = await runPostRegistrationFollowUps(
        registrationSucceeded: false,
        shouldSuggestTrips: true,
        handleWishlist: () async {
          wishlistCalls++;
        },
        handleTripSuggestions: () async {
          suggestionCalls++;
        },
      );

      expect(result, isFalse);

      expect(wishlistCalls, 0);
      expect(suggestionCalls, 0);
    });

    test('follow-ups run sequentially', () async {
      final operations = <String>[];

      final result = await runPostRegistrationFollowUps(
        registrationSucceeded: true,
        shouldSuggestTrips: true,
        handleWishlist: () async {
          operations.add('wishlist-start');

          await Future<void>.delayed(Duration.zero);

          operations.add('wishlist-finished');
        },
        handleTripSuggestions: () async {
          operations.add('trip-suggestions-start');
        },
      );

      expect(result, isTrue);

      expect(operations, [
        'wishlist-start',
        'wishlist-finished',
        'trip-suggestions-start',
      ]);
    });
  });
}
