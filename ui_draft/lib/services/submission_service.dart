import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Did the user organize the event themselves, or find it somewhere else?
/// Reviewers verify the two differently, so it's stored with the submission.
enum SubmissionType { hosted, found }

/// Where a submission is in the review process. Reviewers change the
/// `status` field in the Firebase console; the app only displays it.
enum SubmissionStatus { pending, approved, rejected }

/// What a user fills in on the Add screen.
class EventSubmission {
  final SubmissionType type;
  final String title;
  final String categoryId; // must be a CategoryIds value
  final String org;
  final String location;
  final String description;
  final String url; // already normalized, or '' if none
  final DateTime startsAt;
  final bool hasTime; // false = date only

  const EventSubmission({
    required this.type,
    required this.title,
    required this.categoryId,
    required this.org,
    required this.location,
    required this.description,
    required this.url,
    required this.startsAt,
    required this.hasTime,
  });

  /// Field names match the `events` collection, so an approved submission can
  /// be copied over with only the review fields removed.
  Map<String, dynamic> toFirestore(String submitterUid) => {
        'title': title,
        'categoryId': categoryId,
        'org': org,
        'location': location,
        'description': description,
        'url': url,
        'startsAt': Timestamp.fromDate(startsAt),
        'hasTime': hasTime,
        'submissionType': type.name,
        'submitterUid': submitterUid,
        'status': SubmissionStatus.pending.name,
        'submittedAt': FieldValue.serverTimestamp(),
      };
}

/// One of the signed-in user's own submissions, as shown in "Your submissions".
class MySubmission {
  final String id;
  final String title;
  final String categoryId;
  final DateTime submittedAt;
  final SubmissionStatus status;
  const MySubmission({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.submittedAt,
    required this.status,
  });
}

class SubmissionService {
  SubmissionService._();
  static final SubmissionService instance = SubmissionService._();

  /// Sends the submission for review. Throws [StateError] if nobody is signed
  /// in, and another error if it can't be saved.
  Future<void> submit(EventSubmission s) async {
    final user = AuthService.instance.currentUser;
    if (user == null || user.isAnonymous) throw StateError('Sign in required');

    await FirebaseFirestore.instance
        .collection('submissions')
        .add(s.toFirestore(user.uid))
        // Offline, Firestore writes wait forever; fail so the user is told.
        .timeout(const Duration(seconds: 12));
  }

  /// The signed-in user's own submissions, newest first, updating live when a
  /// reviewer changes a status. Empty if nobody is signed in.
  Stream<List<MySubmission>> watchMine() {
    final user = AuthService.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return FirebaseFirestore.instance
        .collection('submissions')
        .where('submitterUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final items = <MySubmission>[];
      for (final doc in snapshot.docs) {
        try {
          final d = doc.data();
          items.add(MySubmission(
            id: doc.id,
            title: d['title'] as String? ?? 'Untitled event',
            categoryId: d['categoryId'] as String? ?? '',
            // Null briefly after sending, until the server stamps the time.
            submittedAt: (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            status: SubmissionStatus.values.firstWhere(
              (s) => s.name == d['status'],
              orElse: () => SubmissionStatus.pending,
            ),
          ));
        } catch (err) {
          debugPrint('SubmissionService: skipping unreadable submission ${doc.id} ($err)');
        }
      }
      // Sorted here, so no Firestore composite index is needed.
      items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return items;
    });
  }

  /// Returns a cleaned-up http(s) link, or null if it isn't a usable web link.
  /// Accepts "example.org/page" and adds https://.
  static String? normalizeUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (uri.userInfo.isNotEmpty) return null;
    return s;
  }
}
