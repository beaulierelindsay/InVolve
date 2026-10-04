import 'package:flutter/material.dart';
 
class EngagementCategory {
  final String id;
  final String label;
  final String shortLabel; // used on filter chips and event badges
  final String tagline;
  final String description;
  final List<String> examples;
  final IconData icon;
  final Color color;
  final Color lightColor;
 
  const EngagementCategory({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.tagline,
    required this.description,
    required this.examples,
    required this.icon,
    required this.color,
    required this.lightColor,
  });
}
 
/// Single source of truth for category ids.
/// Events, Firestore documents, user preferences, and API mappers
/// should all reference these instead of raw strings.
class CategoryIds {
  static const civic = 'civic';
  static const directService = 'direct-service';
  static const neighborhood = 'neighborhood';
  static const causeAction = 'cause-action';
  static const localCulture = 'local-culture';
  static const mutualAid = 'mutual-aid';
}
 
const List<EngagementCategory> allCategories = [
  EngagementCategory(
    id: CategoryIds.civic,
    label: 'Civic Meetings & Public Hearings',
    shortLabel: 'Civic',
    tagline: 'Your voice in the room',
    description:
        'Show up where decisions get made — zoning boards, city council sessions, school board meetings, budget hearings.',
    examples: ['City council sessions', 'Zoning & land-use hearings', 'School board meetings', 'Budget town halls'],
    icon: Icons.account_balance_outlined,
    color: Color(0xFF1B4D3E),
    lightColor: Color(0xFFE8F0ED),
  ),
  EngagementCategory(
    id: CategoryIds.directService,
    label: 'Direct-Service Volunteering',
    shortLabel: 'Volunteer',
    tagline: 'Hands-on help, real impact',
    description:
        'Work directly with people who need it — food banks, shelters, tutoring, elder care, crisis hotlines, and more.',
    examples: ['Food bank shifts', 'Shelter & housing support', 'Youth tutoring', 'Crisis line volunteering'],
    icon: Icons.favorite_outline,
    color: Color(0xFFC9631A),
    lightColor: Color(0xFFFDF0E6),
  ),
  EngagementCategory(
    id: CategoryIds.neighborhood,
    label: 'Neighborhood Stewardship',
    shortLabel: 'Stewardship',
    tagline: 'Care for the place you share',
    description:
        'Keep local spaces alive — cleanups, tree plantings, community gardens, trail maintenance, and block projects.',
    examples: ['Park & trail cleanups', 'Community garden work', 'Tree planting days', 'Block association projects'],
    icon: Icons.park_outlined,
    color: Color(0xFF2D6A55),
    lightColor: Color(0xFFE4F0EB),
  ),
  EngagementCategory(
    id: CategoryIds.causeAction,
    label: 'Cause Actions',
    shortLabel: 'Causes',
    tagline: 'Move the needle on what matters',
    description:
        'Take concrete steps on issues you care about — petition drives, phone banks, rallies, and advocacy campaigns.',
    examples: ['Petition drives', 'Phone & postcard banks', 'Community rallies', 'Advocacy campaigns'],
    icon: Icons.campaign_outlined,
    color: Color(0xFF5B3A8C),
    lightColor: Color(0xFFEEE8F5),
  ),
  EngagementCategory(
    id: CategoryIds.localCulture,
    label: 'Local Arts & Culture',
    shortLabel: 'Culture',
    tagline: 'Celebrate what makes here, here',
    description:
        'Support creative and cultural life — volunteer at festivals, help local artists, cultural preservation.',
    examples: ['Festival volunteering', 'Community theater', 'Cultural heritage events', 'Library programs'],
    icon: Icons.palette_outlined,
    color: Color(0xFFB5481A),
    lightColor: Color(0xFFFCEEE7),
  ),
  EngagementCategory(
    id: CategoryIds.mutualAid,
    label: 'Mutual Aid & Crisis Support',
    shortLabel: 'Mutual Aid',
    tagline: 'Neighbors helping neighbors',
    description:
        'Community care networks — resource drives, emergency response, redistribution, and resilience projects.',
    examples: ['Resource & supply drives', 'Emergency preparedness', 'Community fridges', 'Elder support networks'],
    icon: Icons.handshake_outlined,
    color: Color(0xFF1A5C8C),
    lightColor: Color(0xFFE6F0F8),
  ),
];
 
/// Look up a category by id. Throws a clear error if an event carries an
/// unknown id, which surfaces schema mismatches early instead of hiding them.
EngagementCategory categoryById(String id) {
  return allCategories.firstWhere(
    (c) => c.id == id,
    orElse: () => throw ArgumentError('Unknown category id: "$id"'),
  );
}
 
/// Free-text labels that might appear in Firestore documents or API data,
/// mapped to canonical category ids. Extend this as new sources are added.
/// (After normalizing: lowercase, "&" -> "and", non-alphanumerics -> "-".)
const Map<String, String> _categoryAliases = {
  'civic-meetings': CategoryIds.civic,
  'civic-meetings-and-public-hearings': CategoryIds.civic,
  'volunteer': CategoryIds.directService,
  'volunteering': CategoryIds.directService,
  'direct-service-volunteering': CategoryIds.directService,
  'stewardship': CategoryIds.neighborhood,
  'neighborhood-stewardship': CategoryIds.neighborhood,
  'environment': CategoryIds.neighborhood,
  'causes': CategoryIds.causeAction,
  'cause': CategoryIds.causeAction,
  'cause-actions': CategoryIds.causeAction,
  'fundraising': CategoryIds.causeAction,
  'culture': CategoryIds.localCulture,
  'arts': CategoryIds.localCulture,
  'arts-culture': CategoryIds.localCulture,
  'arts-and-culture': CategoryIds.localCulture,
  'local-arts-and-culture': CategoryIds.localCulture,
  'mutual-aid-and-crisis-support': CategoryIds.mutualAid,
  'crisis-support': CategoryIds.mutualAid,
};

/// Translate a raw category string (e.g. "Civic", "Volunteer", "civic")
/// into a canonical id, or null if it can't be recognized.
String? categoryIdFromRaw(String? raw) {
  if (raw == null) return null;
  final key = raw
      .trim()
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (key.isEmpty) return null;
  for (final c in allCategories) {
    if (c.id == key) return c.id;
  }
  return _categoryAliases[key];
}
