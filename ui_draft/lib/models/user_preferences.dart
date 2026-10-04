/// What the user told us during onboarding.
///
/// This is the contract between the UI and the ranking logic:
/// - [categoryIds] are EngagementCategory ids (see CategoryIds).
/// - [commitment] is one of 'drop-in' | 'occasional' | 'regular'.
class UserPreferences {
  static const defaultLocation = 'Brooklyn, New York';

  final Set<String> categoryIds;
  final String? commitment;
  final String locationLabel;

  const UserPreferences({
    this.categoryIds = const {},
    this.commitment,
    this.locationLabel = defaultLocation,
  });

  bool get hasInterests => categoryIds.isNotEmpty;

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