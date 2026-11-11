/// Coordinates optional actions after a successful travel registration.
///
/// The travel record has already been persisted before this function runs.
/// Failures in optional follow-ups must never change the registration result.
Future<bool> runPostRegistrationFollowUps({
  required bool registrationSucceeded,
  required bool shouldSuggestTrips,
  required Future<void> Function() handleWishlist,
  required Future<void> Function() handleTripSuggestions,
}) async {
  if (!registrationSucceeded) {
    return false;
  }

  // The Wishlist follow-up is independent of Trip suggestions.
  try {
    await handleWishlist();
  } catch (_) {
    // Registration has already succeeded.
  }

  if (shouldSuggestTrips) {
    try {
      await handleTripSuggestions();
    } catch (_) {
      // A suggestion failure must not invalidate the saved visit.
    }
  }

  return true;
}
