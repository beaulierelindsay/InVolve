import '../models/category.dart';
import '../models/events.dart';

/// Placeholder data for development. Toggle with `_useMockEvents` in feed_page.dart.
const List<Event> kMockEvents = [
  Event(
    id: 'evt-001',
    categoryId: CategoryIds.civic,
    title: 'Community Board 6 Monthly Meeting',
    org: 'Brooklyn Community Board 6',
    date: 'Thu, Sep 24 · 7:00 PM',
    distance: '0.4 mi',
    action: 'Add to calendar',
    description: 'Public session covering zoning proposals, housing updates, and open comment period.',
  ),
  Event(
    id: 'evt-002',
    categoryId: CategoryIds.directService,
    title: 'Weekend Shift — Food Pantry',
    org: 'Park Slope Food Coop',
    date: 'Sat, Sep 27 · 9:00–12:00 AM',
    distance: '0.7 mi',
    action: 'Sign up',
    description: 'Help sort and distribute groceries to 200+ households. All training provided on-site.',
    spots: 4,
  ),
  Event(
    id: 'evt-003',
    categoryId: CategoryIds.neighborhood,
    title: 'Prospect Park Fall Cleanup',
    org: 'Prospect Park Alliance',
    date: 'Sun, Sep 28 · 10:00 AM',
    distance: '1.1 mi',
    action: 'RSVP',
    description: 'Join 60+ volunteers for a seasonal trail and meadow cleanup. Gloves & tools provided.',
    spots: 18,
  ),
  Event(
    id: 'evt-004',
    categoryId: CategoryIds.causeAction,
    title: 'Tenant Rights Letter-Writing Bank',
    org: 'Right to Counsel NYC',
    date: 'Wed, Sep 24 · 6:30 PM',
    distance: '1.8 mi',
    action: 'Join session',
    description: 'Write letters to council members supporting the expansion of free legal counsel for tenants.',
  ),
];
