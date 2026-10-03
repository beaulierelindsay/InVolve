import 'package:cloud_firestore/cloud_firestore.dart';

class EventService {
  final CollectionReference eventsCollection =
      FirebaseFirestore.instance.collection('events');

  Future<List<Map<String, dynamic>>> getEvents() async {
    final snapshot = await eventsCollection.get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'category': data['category'] ?? '',
        'date': data['date'] ?? '',
        'location': data['location'] ?? '',
        'description': data['description'] ?? '',
      };
    }).toList();
  }
}
