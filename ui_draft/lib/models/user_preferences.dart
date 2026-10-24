/// What the user told us during onboarding.
///
/// This is the contract between the UI and the ranking logic:
/// - [categoryIds] are EngagementCategory ids (see CategoryIds).
/// - [commitment] is one of 'drop-in' | 'occasional' | 'regular'.
/// - [locationLabel] is the neighborhood the user typed; empty until they set one.
class UserPreferences {
  /// Where our event sources currently cover. Shown in headers when the user
  /// hasn't picked a neighborhood, so the app never claims a place the user
  /// didn't choose.
  static const serviceArea = 'New York City';

  /// Empty means "not set yet". (Kept under this name so existing code that
  /// refers to it, like PreferencesStore, keeps working.)
  static const defaultLocation = '';

  final Set<String> categoryIds;
  final String? commitment;
  final String locationLabel;

  const UserPreferences({
    this.categoryIds = const {},
    this.commitment,
    this.locationLabel = defaultLocation,
  });

  bool get hasInterests => categoryIds.isNotEmpty;

  bool get hasLocation => locationLabel.trim().isNotEmpty;

  /// What to show in headers: the user's neighborhood, else the service area.
  String get displayLocation => hasLocation ? locationLabel.trim() : serviceArea;

  UserPreferences copyWith({
    Set<String>? categoryIds,
    String? commitment,
    String? locationLabel,
  }) {
    return UserPreferences(
      categoryIds: categoryIds ?? this.categoryIds,
      commitment: commitment ?? this.commitment,
      locationLabel: locationLabel ?? this.locationLabel,
    );
  }

  /// Shape to write to Firestore (users/{uid}) later.
  Map<String, dynamic> toMap() => {
        'categoryIds': categoryIds.toList(),
        'commitment': commitment,
        'locationLabel': locationLabel,
      };
}
