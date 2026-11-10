import 'package:flutter_test/flutter_test.dart';
import 'package:involve/models/events.dart';
import 'package:involve/utils/event_ranking.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8);
  Event event(String id,
          {double? lat = 40, double? lng = -74, int? days = 1}) =>
      Event(
          id: id,
          categoryId: 'civic',
          title: id,
          org: '',
          date: '',
          action: '',
          description: '',
          latitude: lat,
          longitude: lng,
          startsAt: days == null ? null : now.add(Duration(days: days)));
  double score(Event event, {double? userLat = 40}) => eventRankingScore(event,
      userLatitude: userLat, userLongitude: -74, now: now);

  test('a slightly farther event tomorrow beats a close event weeks away', () {
    expect(score(event('tomorrow', lat: 40.05)),
        lessThan(score(event('weeks', days: 21))));
  });
  test('nearer events win when dates match; sooner events win at same place',
      () {
    expect(score(event('near')), lessThan(score(event('far', lat: 41))));
    expect(score(event('soon')), lessThan(score(event('later', days: 2))));
    expect(score(event('soon')), dateWeight);
  });
  test('missing and invalid event data ranks behind complete data', () {
    for (final incomplete in [
      event('no lat', lat: null),
      event('no lng', lng: null),
      event('no date', days: null),
      event('nan', lat: double.nan),
      event('range', lng: 181)
    ]) {
      expect(score(incomplete), double.infinity);
      expect(score(incomplete), greaterThan(score(event('valid'))));
    }
  });
  test('without user coordinates dates still rank and absent dates sort last',
      () {
    expect(score(event('soon', lat: null), userLat: null), dateWeight);
    expect(score(event('later'), userLat: null),
        lessThan(score(event('weeks', days: 21), userLat: null)));
    expect(score(event('undated', days: null), userLat: null), double.infinity);
  });
  test('past events have no negative date penalty and ties are deterministic',
      () {
    expect(score(event('past', days: -1)), 0);
    expect(
        compareEventsForRanking(event('a', days: null), event('b', lat: null),
            userLatitude: 40, userLongitude: -74, now: now),
        lessThan(0));
  });
}
