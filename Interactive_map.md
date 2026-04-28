# NileQuest — Interactive Map Implementation Guide

> **Scope:** User location on Mapbox · Itinerary as a visual route · POI stops with bottom sheets  
> **Stack:** Flutter · `mapbox_maps_flutter` · `DirectionsService` · `LocationService` · `ItineraryEvent` model

---

## Table of Contents

1. [Overview](#1-overview)
2. [Dependencies & Setup](#2-dependencies--setup)
3. [Step 1 — Show the User on the Map](#3-step-1--show-the-user-on-the-map)
4. [Step 2 — Plot Itinerary POIs as Numbered Markers](#4-step-2--plot-itinerary-poi-stops)
5. [Step 3 — Draw the Route Between POIs](#5-step-3--draw-the-route-between-pois)
6. [Step 4 — POI Stop Bottom Sheet](#6-step-4--poi-stop-bottom-sheet)
7. [Step 5 — Day Selector & Multi-Day Support](#7-step-5--day-selector--multi-day-support)
8. [Step 6 — Putting It All Together](#8-step-6--putting-it-all-together)
9. [Data Flow Summary](#9-data-flow-summary)
10. [Checklist](#10-checklist)

---

## 1. Overview

The interactive map has three layers stacked on top of each other inside a single `MapboxMap` widget:

```
┌──────────────────────────────────────────────┐
│  Layer 3 — User location dot (live GPS)      │
│  Layer 2 — Route polyline (directions API)   │
│  Layer 1 — POI numbered stop markers         │
│  Base    — Mapbox tile layer                 │
└──────────────────────────────────────────────┘
```

The screen reads the current `Itinerary` from state, extracts the selected day's `ItineraryEvent` list, and:

1. Pins numbered markers at each POI's `lat/lon`
2. Fetches a driving/walking route through all stops via `DirectionsService`
3. Draws the polyline connecting them
4. Shows the live user dot via Mapbox's built-in location component
5. Opens a `DraggableScrollableSheet` when the user taps a stop

---

## 2. Dependencies & Setup

### pubspec.yaml

All packages below are already present in NileQuest. No new dependencies required.

```yaml
dependencies:
  mapbox_maps_flutter: ^2.x.x       # Map rendering + location component
  flutter_polyline_points: ^2.x.x   # Decode Google encoded polylines
  geolocator: ^11.x.x               # Get device GPS coordinates
  cached_network_image: ^3.x.x      # POI photos in bottom sheet
  http: ^1.x.x                      # Already used by DirectionsService
```

### Mapbox token

Already initialised in `lib/main.dart`:

```dart
MapboxOptions.setAccessToken('YOUR_MAPBOX_PUBLIC_TOKEN');
```

### Android permissions — `AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

---

## 3. Step 1 — Show the User on the Map

### 3.1 Request location permission

Call this once when the screen initialises, using your existing `LocationService`:

```dart
// lib/screens/map_screen.dart

import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Request permission
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    // Get current position
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() => _userPosition = pos);

    // Centre camera on the user
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(pos.longitude, pos.latitude),
        ),
        zoom: 13.5,
        pitch: 30,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }
}
```

### 3.2 Enable the Mapbox location puck

The **location puck** is Mapbox's built-in animated user dot. Enable it after the map loads:

```dart
void _onMapCreated(MapboxMap mapboxMap) async {
  _mapboxMap = mapboxMap;

  // Enable the pulsing blue location dot
  await mapboxMap.location.updateSettings(
    LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF1D9E75,   // NileQuest teal
      pulsingMaxRadius: 50.0,
      accuracyRingEnabled: true,
      accuracyRingColor: 0x221D9E75,
    ),
  );
}
```

### 3.3 Wire the map widget

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: MapWidget(
      key: const ValueKey('itinerary-map'),
      onMapCreated: _onMapCreated,
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            _userPosition?.longitude ?? 31.2357,   // Cairo fallback
            _userPosition?.latitude  ?? 30.0444,
          ),
        ),
        zoom: 12.0,
      ),
    ),
  );
}
```

---

## 4. Step 2 — Plot Itinerary POI Stops

Each `ItineraryEvent` in the day's list has a `poi.lat` and `poi.lon`. We add them as a GeoJSON source with sequential numbering.

### 4.1 Build the GeoJSON FeatureCollection

```dart
// Convert today's itinerary events → GeoJSON
Map<String, dynamic> _buildStopsGeoJson(List<ItineraryEvent> events) {
  final features = events.asMap().entries.map((entry) {
    final index = entry.key;
    final event = entry.value;

    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [event.poi.lon, event.poi.lat],
      },
      'properties': {
        'stopNumber': index + 1,          // "1", "2", "3" …
        'name': event.poi.name,
        'category': event.poi.category,
        'startTime': event.startTime,
        'endTime': event.endTime,
        'cost': event.poi.cost,
        'duration': event.poi.duration,
        'photoUrl': event.poi.photoUrl ?? '',
        'reason': event.reason,
      },
    };
  }).toList();

  return {
    'type': 'FeatureCollection',
    'features': features,
  };
}
```

### 4.2 Add source + circle + label layers

```dart
Future<void> _addStopMarkers(List<ItineraryEvent> events) async {
  final map = _mapboxMap;
  if (map == null) return;

  final geoJson = _buildStopsGeoJson(events);

  // Remove previous layers if re-drawing for a new day
  try {
    await map.style.removeStyleLayer('stop-labels');
    await map.style.removeStyleLayer('stop-circles');
    await map.style.removeStyleSource('itinerary-stops');
  } catch (_) {}

  // Add GeoJSON source
  await map.style.addSource(
    GeoJsonSource(
      id: 'itinerary-stops',
      data: jsonEncode(geoJson),
    ),
  );

  // Circle layer — teal filled circles
  await map.style.addLayer(
    CircleLayer(
      id: 'stop-circles',
      sourceId: 'itinerary-stops',
      circleRadius: 18.0,
      circleColor: 0xFF1D9E75,         // NileQuest teal
      circleStrokeWidth: 2.5,
      circleStrokeColor: 0xFFFFFFFF,   // White border
    ),
  );

  // Symbol layer — stop numbers on top of circles
  await map.style.addLayer(
    SymbolLayer(
      id: 'stop-labels',
      sourceId: 'itinerary-stops',
      textField: '{stopNumber}',
      textSize: 13.0,
      textColor: 0xFFFFFFFF,
      textFont: ['DIN Pro Bold', 'Arial Unicode MS Bold'],
    ),
  );
}
```

### 4.3 Handle marker taps

```dart
void _setupTapListener() {
  _mapboxMap?.onMapTapListener = (MapContentGestureContext ctx) async {
    final features = await _mapboxMap!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(ctx.touchPosition),
      RenderedQueryOptions(layerIds: ['stop-circles', 'stop-labels']),
    );

    if (features.isNotEmpty) {
      final props = features.first.feature['properties'] as Map;
      _showStopBottomSheet(props);
    }
  };
}
```

---

## 5. Step 3 — Draw the Route Between POIs

### 5.1 Fetch the polyline from DirectionsService

Your existing `DirectionsService` calls the Google Directions API. Extend it to accept a **list of waypoints** for multi-stop routing:

```dart
// lib/services/directions_service.dart (extend existing)

Future<String?> getMultiStopPolyline(List<LatLng> stops) async {
  if (stops.length < 2) return null;

  final origin      = '${stops.first.latitude},${stops.first.longitude}';
  final destination = '${stops.last.latitude},${stops.last.longitude}';

  // Waypoints = all stops between first and last
  final waypoints = stops
      .sublist(1, stops.length - 1)
      .map((s) => '${s.latitude},${s.longitude}')
      .join('|');

  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json'
    '?origin=$origin'
    '&destination=$destination'
    '${waypoints.isNotEmpty ? '&waypoints=optimize:false|$waypoints' : ''}'
    '&mode=walking'          // walking suits tourist itineraries
    '&key=$_googleApiKey',
  );

  final response = await http.get(url);
  if (response.statusCode != 200) return null;

  final data = jsonDecode(response.body);
  if (data['routes'].isEmpty) return null;

  // Google returns one overview_polyline for the full multi-stop route
  return data['routes'][0]['overview_polyline']['points'] as String;
}
```

### 5.2 Decode and draw the polyline on Mapbox

```dart
Future<void> _drawRoute(List<ItineraryEvent> events) async {
  final map = _mapboxMap;
  if (map == null || events.length < 2) return;

  // Build LatLng list from POI coordinates
  final stops = events
      .map((e) => LatLng(e.poi.lat, e.poi.lon))
      .toList();

  // Fetch encoded polyline from Directions API
  final encoded = await DirectionsService().getMultiStopPolyline(stops);
  if (encoded == null) return;

  // Decode polyline points
  final points = PolylinePoints()
      .decodePolyline(encoded)
      .map((p) => [p.longitude, p.latitude])
      .toList();

  // Remove previous route layer
  try {
    await map.style.removeStyleLayer('route-line');
    await map.style.removeStyleSource('route-source');
  } catch (_) {}

  // Add LineString source
  await map.style.addSource(
    GeoJsonSource(
      id: 'route-source',
      data: jsonEncode({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': points,
        },
      }),
    ),
  );

  // Draw line layer BELOW the stop markers
  await map.style.addLayerAt(
    LineLayer(
      id: 'route-line',
      sourceId: 'route-source',
      lineColor: 0xFF1D9E75,     // NileQuest teal
      lineWidth: 4.0,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
      lineDasharray: [1.0, 0.0], // solid line; use [2.0, 1.0] for dashed
    ),
    LayerPosition.below('stop-circles'), // route goes under the markers
  );
}
```

### 5.3 Fit camera to show the full route

```dart
Future<void> _fitCameraToRoute(List<ItineraryEvent> events) async {
  if (_mapboxMap == null || events.isEmpty) return;

  final lats = events.map((e) => e.poi.lat).toList();
  final lons = events.map((e) => e.poi.lon).toList();

  // Also include the user's position in the bounds
  if (_userPosition != null) {
    lats.add(_userPosition!.latitude);
    lons.add(_userPosition!.longitude);
  }

  final bounds = CoordinateBounds(
    southwest: Point(
      coordinates: Position(
        lons.reduce(min),
        lats.reduce(min),
      ),
    ),
    northeast: Point(
      coordinates: Position(
        lons.reduce(max),
        lats.reduce(max),
      ),
    ),
    infiniteBounds: false,
  );

  await _mapboxMap!.cameraForCoordinateBounds(
    bounds,
    MbxEdgeInsets(top: 100, left: 60, bottom: 200, right: 60),
    null,
    null,
    null,
    null,
  ).then((camera) {
    _mapboxMap!.flyTo(
      camera,
      MapAnimationOptions(duration: 1000),
    );
  });
}
```

---

## 6. Step 4 — POI Stop Bottom Sheet

When the user taps a stop marker, show a `DraggableScrollableSheet` with the POI details.

```dart
void _showStopBottomSheet(Map props) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: _StopSheetContent(props: props),
        ),
      ),
    ),
  );
}
```

### Bottom sheet content widget

```dart
class _StopSheetContent extends StatelessWidget {
  final Map props;
  const _StopSheetContent({required this.props});

  @override
  Widget build(BuildContext context) {
    final stopNum  = props['stopNumber']?.toString() ?? '?';
    final name     = props['name'] ?? '';
    final category = props['category'] ?? '';
    final start    = props['startTime'] ?? '';
    final end      = props['endTime'] ?? '';
    final cost     = props['cost']?.toString() ?? '0';
    final photoUrl = props['photoUrl'] ?? '';
    final reason   = props['reason'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // POI photo
        if (photoUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: photoUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stop badge + name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Stop $stopNum',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                category,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),

              const SizedBox(height: 12),

              // Time + cost row
              Row(
                children: [
                  const Icon(Icons.access_time, size: 15, color: Color(0xFF1D9E75)),
                  const SizedBox(width: 4),
                  Text(
                    '$start – $end',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.payments_outlined, size: 15, color: Color(0xFF1D9E75)),
                  const SizedBox(width: 4),
                  Text(
                    '${cost} EGP',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),

              // AI reason
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF085041)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Navigate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: launch Google Maps navigation deep link
                    final lat = props['lat'];
                    final lon = props['lon'];
                    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking';
                    launchUrl(Uri.parse(url));
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Navigate here'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

---

## 7. Step 5 — Day Selector & Multi-Day Support

The itinerary has multiple days. Add a chip row at the top of the map so the user can switch days and see each day's route.

```dart
// State
int _selectedDay = 1;

// Inside build(), overlay a chip row on top of the map
Widget _buildDaySelector(Itinerary itinerary) {
  return Positioned(
    top: MediaQuery.of(context).padding.top + 12,
    left: 12,
    right: 12,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(itinerary.totalDays, (i) {
          final day = i + 1;
          final isSelected = _selectedDay == day;
          return GestureDetector(
            onTap: () async {
              setState(() => _selectedDay = day);
              final events = itinerary.itinerary['day_$day'] ?? [];
              await _addStopMarkers(events);
              await _drawRoute(events);
              await _fitCameraToRoute(events);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1D9E75)
                    : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Day $day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}
```

---

## 8. Step 6 — Putting It All Together

### Full `MapScreen` skeleton

```dart
// lib/screens/map_screen.dart

import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/itinerary.dart';
import '../models/itinerary_event.dart';
import '../services/directions_service.dart';

class MapScreen extends StatefulWidget {
  final Itinerary itinerary;
  const MapScreen({Key? key, required this.itinerary}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  Position?  _userPosition;
  int _selectedDay = 1;
  bool _isLoading  = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      setState(() => _isLoading = false);
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _userPosition = pos;
      _isLoading    = false;
    });
  }

  // ── Map creation ────────────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Enable location puck
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF1D9E75,
      accuracyRingEnabled: true,
    ));

    // Draw the first day immediately
    final events = _eventsForDay(_selectedDay);
    await _addStopMarkers(events);
    await _drawRoute(events);
    await _fitCameraToRoute(events);
    _setupTapListener();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<ItineraryEvent> _eventsForDay(int day) {
    return widget.itinerary.itinerary['day_$day'] ?? [];
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Base map
          MapWidget(
            key: const ValueKey('itinerary-map'),
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  _userPosition?.longitude ?? 31.2357,
                  _userPosition?.latitude  ?? 30.0444,
                ),
              ),
              zoom: 12.0,
            ),
          ),

          // Day selector chips
          if (!_isLoading)
            _buildDaySelector(widget.itinerary),

          // Loading indicator
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  // All methods from Steps 1–5 live here:
  // _initLocation(), _onMapCreated(), _buildStopsGeoJson(),
  // _addStopMarkers(), _drawRoute(), _fitCameraToRoute(),
  // _setupTapListener(), _showStopBottomSheet(), _buildDaySelector()
}
```

---

## 9. Data Flow Summary

```
App State (Itinerary)
        │
        ▼
MapScreen.initState()
  ├─ _initLocation()        → Geolocator → userPosition
  └─ _onMapCreated()
        ├─ LocationComponentSettings  → Mapbox blue puck
        ├─ _eventsForDay(1)           → List<ItineraryEvent>
        ├─ _buildStopsGeoJson()       → GeoJSON FeatureCollection
        ├─ _addStopMarkers()          → GeoJsonSource + CircleLayer + SymbolLayer
        ├─ _drawRoute()
        │     ├─ DirectionsService.getMultiStopPolyline()
        │     ├─ PolylinePoints().decodePolyline()
        │     └─ GeoJsonSource + LineLayer (below markers)
        ├─ _fitCameraToRoute()        → camera bounds to fit all stops
        └─ _setupTapListener()        → queryRenderedFeatures → bottom sheet

Day selector tap
        └─ setState(selectedDay) → re-run addStopMarkers + drawRoute + fitCamera

Marker tap
        └─ queryRenderedFeatures → _showStopBottomSheet(props)
              └─ DraggableScrollableSheet
                    ├─ POI photo (CachedNetworkImage)
                    ├─ stop number badge + name
                    ├─ time range + cost
                    ├─ AI reason card
                    └─ Navigate button → url_launcher (Google Maps)
```

---

## 10. Checklist

Use this checklist before testing on a physical device:

- [ ] `ACCESS_FINE_LOCATION` permission in `AndroidManifest.xml`
- [ ] Mapbox token set in `main.dart` via `MapboxOptions.setAccessToken()`
- [ ] Google Directions API key in `DirectionsService` (same key as existing)
- [ ] `itinerary.itinerary` map uses `'day_1'`, `'day_2'` keys — confirm this matches your `Itinerary.fromJson()` output
- [ ] `ItineraryEvent.poi.lat` / `.lon` are non-null for all events
- [ ] `LayerPosition.below('stop-circles')` — ensure the layer ID exists before referencing it
- [ ] Test with a 1-day itinerary first, then 3-day to confirm day selector works
- [ ] Verify `_fitCameraToRoute()` doesn't crash when only 1 event exists (guard: `if (events.length < 2) return`)
- [ ] On physical device, confirm location permission dialog appears on first launch
- [ ] Bottom sheet `launchUrl` — ensure `url_launcher` is correctly configured for Android deep links

---

## Notes

**Walking vs driving mode** — tourist itineraries in Cairo are better served with `mode=walking` for short hops or `mode=driving` for cross-city days. Consider exposing this as a toggle in the bottom sheet.

**Route optimisation** — the `DirectionsService` call uses `optimize:false` so the route follows your AI's pre-ordered schedule. Do not change this to `optimize:true` — it will reorder the stops and contradict the itinerary.

**Performance** — call `_addStopMarkers()` and `_drawRoute()` only when the selected day changes, not on every frame or map move. The 24h cache in `PlacesService` already handles POI data; the Directions API call is the only network request triggered per day switch.

**Offline** — for offline support, download Mapbox tiles for the city region using the Mapbox Offline API before the trip. The polyline and marker data is already small enough to cache in `SharedPreferences` alongside the itinerary JSON.