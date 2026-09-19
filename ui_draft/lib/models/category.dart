import 'package:flutter/material.dart';

class EngagementCategory {
  final String id;
  final String label;
  final String tagline;
  final String description;
  final List<String> examples;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const EngagementCategory({
    required this.id,
    required this.label,
    required this.tagline,
    required this.description,
    required this.examples,
    required this.icon,
    required this.color,
    required this.lightColor,
  });
}

const List<EngagementCategory> allCategories = [
  EngagementCategory(
    id: 'civic',
    label: 'Civic Meetings & Public Hearings',
    tagline: 'Your voice in the room',
    description:
        'Show up where decisions get made — zoning boards, city council sessions, school board meetings, budget hearings.',
    examples: ['City council sessions', 'Zoning & land-use hearings', 'School board meetings', 'Budget town halls'],
    icon: Icons.account_balance_outlined,
    color: Color(0xFF1B4D3E),
    lightColor: Color(0xFFE8F0ED),
  ),
  EngagementCategory(
    id: 'direct-service',
    label: 'Direct-Service Volunteering',
    tagline: 'Hands-on help, real impact',
    description:
        'Work directly with people who need it — food banks, shelters, tutoring, elder care, crisis hotlines, and more.',
    examples: ['Food bank shifts', 'Shelter & housing support', 'Youth tutoring', 'Crisis line volunteering'],
    icon: Icons.favorite_outline,
    color: Color(0xFFC9631A),
    lightColor: Color(0xFFFDF0E6),
  ),
  EngagementCategory(
    id: 'neighborhood',
    label: 'Neighborhood Stewardship',
    tagline: 'Care for the place you share',
    description:
        'Keep local spaces alive — cleanups, tree plantings, community gardens, trail maintenance, and block projects.',
    examples: ['Park & trail cleanups', 'Community garden work', 'Tree planting days', 'Block association projects'],
    icon: Icons.park_outlined,
    color: Color(0xFF2D6A55),
    lightColor: Color(0xFFE4F0EB),
  ),
  EngagementCategory(
    id: 'cause-action',
    label: 'Cause Actions',
    tagline: 'Move the needle on what matters',
    description:
        'Take concrete steps on issues you care about — petition drives, phone banks, rallies, and advocacy campaigns.',
    examples: ['Petition drives', 'Phone & postcard banks', 'Community rallies', 'Advocacy campaigns'],
    icon: Icons.campaign_outlined,
    color: Color(0xFF5B3A8C),
    lightColor: Color(0xFFEEE8F5),
  ),
  EngagementCategory(
    id: 'local-culture',
    label: 'Local Arts & Culture',
    tagline: 'Celebrate what makes here, here',
    description:
        'Support creative and cultural life — volunteer at festivals, help local artists, cultural preservation.',
    examples: ['Festival volunteering', 'Community theater', 'Cultural heritage events', 'Library programs'],
    icon: Icons.palette_outlined,
    color: Color(0xFFB5481A),
    lightColor: Color(0xFFFCEEE7),
  ),
  EngagementCategory(
    id: 'mutual-aid',
    label: 'Mutual Aid & Crisis Support',
    tagline: 'Neighbors helping neighbors',
    description:
        'Community care networks — resource drives, emergency response, redistribution, and resilience projects.',
    examples: ['Resource & supply drives', 'Emergency preparedness', 'Community fridges', 'Elder support networks'],
    icon: Icons.handshake_outlined,
    color: Color(0xFF1A5C8C),
    lightColor: Color(0xFFE6F0F8),
  ),
];
