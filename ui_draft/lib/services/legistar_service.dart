import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/events.dart';

/// Fetches public meetings and hearings from the Legistar Web API.
/// Docs: https://webapi.legistar.com/Help
///
/// The token is supplied at build time so it stays out of source control:
///   flutter run --dart-define-from-file=legistar.json
class LegistarService {
  static const _token = String.fromEnvironment('LEGISTAR_TOKEN');

  final String client; // Legistar client id, e.g. 'nyc'
  final String orgName; // shown on event cards
  final http.Client _http;

  LegistarService({
    this.client = 'nyc',
    this.orgName = 'NYC Council',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Upcoming meetings within [days], soonest first. Deferred (postponed)
  /// meetings are dropped since nobody can attend them.
  Future<List<Event>> fetchUpcomingEvents({int days = 30}) async {
    if (_token.isEmpty) {
      throw StateError(
          'LEGISTAR_TOKEN not set. Run with --dart-define-from-file=legistar.json');
    }

    final now = DateTime.now();
    final from = _odataDate(now);
    final to = _odataDate(now.add(Duration(days: days)));
    final uri = Uri.https('webapi.legistar.com', '/v1/$client/events', {
      'token': _token,
      r'$filter': "EventDate ge datetime'$from' and EventDate lt datetime'$to'",
      r'$orderby': 'EventDate asc',
    });

    final response = await _http.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Legistar returned ${response.statusCode}: ${response.reasonPhrase}',
          uri.replace(queryParameters: {})); // don't leak the token in logs
    }

    final items = jsonDecode(response.body) as List<dynamic>;
    final events = items
        .cast<Map<String, dynamic>>()
        .where((e) => e['EventAgendaStatusName'] != 'Deferred')
        .map((e) => Event.fromLegistar(e, org: orgName))
        .toList()
      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
    return events;
  }

  static String _odataDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
