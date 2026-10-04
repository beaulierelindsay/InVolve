import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/user_preferences.dart';

/// App-wide holder for the user's onboarding choices.
///
/// Uses only Flutter built-ins for state (ChangeNotifier), so no extra
/// state-management package is needed. Read with
/// `PreferencesStore.instance.prefs`; listen with addListener or
/// ListenableBuilder.
///
/// When Firebase Auth is ready, swap the SharedPreferences calls in
/// load()/update() for reads/writes to users/{uid}. Nothing else changes.
class PreferencesStore extends ChangeNotifier {
  PreferencesStore._();
  static final PreferencesStore instance = PreferencesStore._();

  static const _kCategories = 'pref_category_ids';
  static const _kCommitment = 'pref_commitment';
  static const _kLocation = 'pref_location_label';

  UserPreferences _prefs = const UserPreferences();
  UserPreferences get prefs => _prefs;

  /// Call once in main() before runApp().
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final validIds = allCategories.map((c) => c.id).toSet();
    _prefs = UserPreferences(
      // Drop any stored ids that no longer exist (e.g. after a rename).
      categoryIds: (sp.getStringList(_kCategories) ?? const <String>[])
          .where(validIds.contains)
          .toSet(),
      commitment: sp.getString(_kCommitment),
      locationLabel: sp.getString(_kLocation) ?? UserPreferences.defaultLocation,
    );
    notifyListeners();
  }

  Future<void> update(UserPreferences next) async {
    _prefs = next;
    notifyListeners();

    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kCategories, next.categoryIds.toList());
    if (next.commitment != null) {
      await sp.setString(_kCommitment, next.commitment!);
    } else {
      await sp.remove(_kCommitment);
    }
    await sp.setString(_kLocation, next.locationLabel);
  }

  Future<void> setLocation(String label) =>
      update(_prefs.copyWith(locationLabel: label));
}