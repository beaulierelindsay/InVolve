import 'package:flutter_test/flutter_test.dart';
import 'package:involve/models/category.dart';
import 'package:involve/models/events.dart';

void main() {
  test('maps a Legistar event to an Event', () {
    final event = Event.fromLegistar({
      'EventId': 22615,
      'EventBodyName': 'Subcommittee on Zoning and Franchises',
      'EventDate': '2026-10-06T00:00:00',
      'EventTime': '1:30 PM',
      'EventLocation': '250 Broadway - 8th Floor - Hearing Room 3',
      'EventComment': 'VOTE',
      'EventInSiteURL': 'https://nyc.legistar.com/MeetingDetail.aspx?LEGID=22615',
    }, org: 'NYC Council');

    expect(event.id, 'legistar-22615');
    expect(event.categoryId, CategoryIds.civic);
    expect(event.title, 'Subcommittee on Zoning and Franchises');
    expect(event.startsAt, DateTime(2026, 10, 6, 13, 30));
    expect(event.date, 'Tue, Oct 6 · 1:30 PM');
    expect(event.location, '250 Broadway - 8th Floor - Hearing Room 3');
    expect(event.description, 'VOTE');
  });

  test('handles missing time and comment', () {
    final event = Event.fromLegistar({
      'EventId': 1,
      'EventBodyName': 'City Council',
      'EventDate': '2026-10-08T00:00:00',
      'EventTime': null,
      'EventComment': null,
    }, org: 'NYC Council');

    expect(event.date, 'Thu, Oct 8');
    expect(event.description, contains('City Council'));
  });
}
