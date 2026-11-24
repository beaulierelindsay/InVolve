import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../app_theme.dart';
import '../models/events.dart';
import '../services/event_service.dart';
import '../services/location_service.dart';
import '../services/preferences_store.dart';
import '../services/saved_events_store.dart';
import '../utils/coordinates.dart';
import '../utils/distance.dart';

const _nycCenter = LatLng(40.7128, -74.0060);
const _nycZoom = 10.5;
const _nearUserZoom = 12.5;
// Events farther than this from the user are left off the map.
const _nearbyRadiusMiles = 25.0;

const _userDotColor = '#757575'; // gray
const _otherEventColor = '#5B3A8C'; // purple: nearby, not for you
const _forYouColor = '#1B4D3E'; // forest green: matches your interests
const _goingColor = '#1A5C8C'; // blue: you signed up / saved

enum _Kind { other, forYou, going }

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  MapLibreMapController? _controller;
  StreamSubscription<List<Event>>? _subscription;
  List<Event> _events = const [];
  final Map<String, Event> _eventByCircleId = {};
  Event? _selected;
  bool _styleLoaded = false;
  bool _syncing = false;
  bool _syncAgain = false;
  Object? _loadError;

  late final CameraPosition _initialCamera = _initialCameraPosition();

  CameraPosition _initialCameraPosition() {
    final lat = LocationService.instance.latitude;
    final lng = LocationService.instance.longitude;
    if (hasValidCoordinates(lat, lng)) {
      return CameraPosition(target: LatLng(lat!, lng!), zoom: _nearUserZoom);
    }
    return const CameraPosition(target: _nycCenter, zoom: _nycZoom);
  }

  @override
  void initState() {
    super.initState();
    PreferencesStore.instance.addListener(_onPrefsChanged);
    SavedEventsStore.instance.addListener(_onPrefsChanged);
    _subscription = EventService().watchEvents().listen(
      (events) {
        _events = events;
        _loadError = null;
        if (mounted) setState(() {});
        _syncMarkers();
      },
      onError: (Object error) {
        if (mounted) setState(() => _loadError = error);
      },
    );
  }

  @override
  void dispose() {
    PreferencesStore.instance.removeListener(_onPrefsChanged);
    SavedEventsStore.instance.removeListener(_onPrefsChanged);
    _subscription?.cancel();
    _controller?.onCircleTapped.remove(_onCircleTapped);
    super.dispose();
  }

  /// All events with coordinates that are near the user (or all of them when
  /// the user's location is unknown).
  List<Event> get _mappableEvents {
    final lat = LocationService.instance.latitude;
    final lng = LocationService.instance.longitude;
    final hasUser = hasValidCoordinates(lat, lng);
    return _events
        .where((e) => hasValidCoordinates(e.latitude, e.longitude))
        .where((e) =>
            !hasUser ||
            distanceInMiles(lat!, lng!, e.latitude!, e.longitude!) <=
                _nearbyRadiusMiles)
        .toList();
  }

  _Kind _kindOf(Event e) {
    if (SavedEventsStore.instance.isSaved(e.id)) return _Kind.going;
    final prefs = PreferencesStore.instance.prefs;
    if (prefs.hasInterests && prefs.categoryIds.contains(e.categoryId)) {
      return _Kind.forYou;
    }
    return _Kind.other;
  }

  static String _colorFor(_Kind k) => switch (k) {
        _Kind.going => _goingColor,
        _Kind.forYou => _forYouColor,
        _Kind.other => _otherEventColor,
      };

  void _onPrefsChanged() {
    if (mounted) setState(() {});
    _syncMarkers();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    _syncMarkers();
  }

  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        // Draw order = stacking order: other, then for-you, then going.
        final events = _mappableEvents
          ..sort((a, b) => _kindOf(a).index.compareTo(_kindOf(b).index));
        await controller.clearCircles();
        _eventByCircleId.clear();
        if (events.isNotEmpty) {
          final circles = await controller.addCircles(
            [
              for (final e in events)
                CircleOptions(
                  geometry: LatLng(e.latitude!, e.longitude!),
                  circleRadius: 9,
                  circleColor: _colorFor(_kindOf(e)),
                  circleStrokeColor: '#FFFFFF',
                  circleStrokeWidth: 2.5,
                ),
            ],
            [
              for (final e in events) {'eventId': e.id}
            ],
          );
          for (var i = 0; i < circles.length; i++) {
            _eventByCircleId[circles[i].id] = events[i];
          }
        }
        // User location dot, added last so it sits on top.
        final lat = LocationService.instance.latitude;
        final lng = LocationService.instance.longitude;
        if (hasValidCoordinates(lat, lng)) {
          await controller.addCircle(CircleOptions(
            geometry: LatLng(lat!, lng!),
            circleRadius: 8,
            circleColor: _userDotColor,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3,
          ));
        }
        final selected = _selected;
        if (selected != null && mounted) {
          final stillThere = events.where((e) => e.id == selected.id);
          setState(
              () => _selected = stillThere.isEmpty ? null : stillThere.first);
        }
      } while (_syncAgain);
    } catch (_) {
    } finally {
      _syncing = false;
    }
  }

  void _onCircleTapped(Circle circle) {
    final event = _eventByCircleId[circle.id];
    if (event != null && mounted) setState(() => _selected = event);
  }

  @override
  Widget build(BuildContext context) {
    final count = _mappableEvents.length;
    final chipText = _loadError != null
        ? "Couldn't load events"
        : '$count ${count == 1 ? 'event' : 'events'} near you';

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.canvas,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    PreferencesStore.instance.prefs.displayLocation
                        .toUpperCase(),
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: AppColors.amber)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.fraunces(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: AppColors.ink),
                    children: const [
                      TextSpan(text: 'Explore the '),
                      TextSpan(
                          text: 'map',
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
                Divider(height: 20, color: AppColors.border),
              ],
            ),
          ),

          // Map area
          Expanded(
            child: Stack(
              children: [
                MapLibreMap(
                  styleString: MapLibreStyles.openfreemapLiberty,
                  initialCameraPosition: _initialCamera,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  onMapClick: (point, latLng) {
                    if (_selected != null) setState(() => _selected = null);
                  },
                  attributionEnabled: true,
                  attributionButtonPosition: AttributionButtonPosition.topRight,
                  attributionButtonMargins: const Point(8, 8),
                  compassEnabled: false,
                ),

                // Floating chip
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: AppColors.amber,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(chipText,
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_selected == null)
                  const Positioned(left: 16, bottom: 16, child: _Legend()),

                if (_selected != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _EventPreview(
                      event: _selected!,
                      onClose: () => setState(() => _selected = null),
                      onOpen: () =>
                          context.push('/feed/event', extra: _selected),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5))),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.ink)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        item(const Color(0xFF757575), 'You'),
        item(AppColors.blue, 'Going'),
        item(AppColors.forest, 'For you'),
        item(AppColors.purple, 'Nearby'),
      ]),
    );
  }
}

class _EventPreview extends StatelessWidget {
  final Event event;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  const _EventPreview(
      {required this.event, required this.onClose, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final location = event.location?.trim() ?? '';
    final date = event.date.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: AppColors.ink)),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(date,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.amber)),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.inkMuted)),
                ],
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    textStyle: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('View details'),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, size: 18, color: AppColors.inkMuted),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}
