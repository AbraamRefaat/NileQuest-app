# NileQuest — Complete Project Overview

> AI-powered Egyptian travel planner with artifact recognition, personalized itinerary generation, interactive maps, and live event discovery.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Backends & External Services](#backends--external-services)
3. [Flutter App Structure](#flutter-app-structure)
4. [Screens](#screens)
5. [Services](#services)
6. [Data Models](#data-models)
7. [CV Feature — "Who Am I?"](#cv-feature--who-am-i)
8. [AI Recommendation Engine](#ai-recommendation-engine)
9. [Dependencies](#dependencies)
10. [Configuration Notes](#configuration-notes)

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   Flutter App (Mobile)                │
│                                                      │
│  Firebase Auth ─── Mapbox Maps ─── Google Places    │
│  Weather API   ─── Image Picker ─── URL Launcher    │
└──────────┬───────────────┬──────────────┬───────────┘
           │               │              │
  ┌────────▼──────┐ ┌──────▼──────┐ ┌───▼────────────┐
  │  AWS EC2      │ │  Hugging    │ │    Vercel       │
  │  Recommend.   │ │  Face Space │ │  (2 backends)   │
  │  Engine       │ │  CV Model   │ │                 │
  │  /recommend   │ │  /predict   │ │  Trips storage  │
  │  /health      │ │             │ │  Tazkarti events│
  └───────────────┘ └─────────────┘ └────────────────┘
```

---

## Backends & External Services

### 1. AI Recommendation Engine — AWS EC2

The main itinerary generation backend. Previously hosted on Railway, now running on **AWS EC2**.

- **Previous URL:** `https://web-production-f68ec.up.railway.app` *(Railway — deprecated)*
- **Current URL:** AWS EC2 instance *(update `lib/services/server_config.dart` `_getDefaultUrl()`)*
- **Stack:** Python · FastAPI · SentenceTransformers · CrossEncoder · scikit-learn · PyTorch
- **Endpoints:**
  - `POST /recommend` — receives user preferences JSON, returns a full day-by-day itinerary
  - `GET /health` — health check, used by `ServerWarmer` to prevent cold starts

**What the engine does:**
1. Converts user interests into semantic embeddings via **SentenceTransformer**
2. Searches 150+ Egyptian POIs using vector similarity
3. Re-ranks candidates with a **CrossEncoder** model
4. Scores each POI against budget, pace, diversity, and travel distance
5. Builds an optimized daily schedule with times, costs, and travel legs

> To update the EC2 URL open `lib/services/server_config.dart` and replace the return value of `_getDefaultUrl()`.

---

### 2. CV Artifact Identification — Hugging Face Space

**Endpoint:** `https://abraam-refaat-egypt-artifact-api.hf.space/predict`  
**Method:** `POST` multipart/form-data (field: `file`)  
**Stack:** Python · FastAPI · image classification model hosted on Hugging Face Spaces

**What it does:**  
Receives a photo of an Egyptian artifact or monument and returns:

| Field | Type | Description |
|-------|------|-------------|
| `recognized` | bool | Whether the artifact was identified |
| `character` | string | Name of the artifact/figure (e.g. "Tutankhamun") |
| `brief` | string | Historical description |
| `confidence` | float | Confidence score (0–1) |

**Supported artifacts include:** Tutankhamun, Nefertiti, the Great Sphinx, Egyptian monuments and mummies.

---

### 3. Trip Storage Backend — Vercel

**Base URL:** `https://trip-backend-iota.vercel.app`  
**Endpoint:** `/api/trips`

Provides REST persistence for saved itineraries. Trips are scoped to the logged-in user's Firebase UID.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/api/trips` | Save a new trip with photo URLs injected |
| `GET` | `/api/trips?uid=<uid>` | Fetch all trips for a user |
| `DELETE` | `/api/trips?id=<tripId>` | Delete a trip |

---

### 4. Tazkarti Events Backend — Vercel

**Base URL:** `https://tazkarti-backend.vercel.app`  
**Endpoint:** `/api/events/music`

Proxies and scrapes music events from [tazkarti.com](https://www.tazkarti.com) (Egypt's ticket platform). The backend filters and returns events as structured JSON; the Flutter app displays them on the Home screen.

---

### 5. Google Maps Platform

Used across multiple services:

| API | Used In |
|-----|---------|
| Places API (Nearby Search, Details, Photos) | `PlacesService` |
| Directions API | `DirectionsService` |
| Distance Matrix API | `DistanceMatrixService` |
| Routes API (traffic-aware) | `NavigationSdkService` |
| Street View & Geolocation | `LocationService` |

---

### 6. Mapbox Maps Flutter

Interactive map rendering with custom markers, cluster layers, and polyline routes.  
Token configured in `lib/main.dart` at app initialization.

---

### 7. Firebase

| Product | Usage |
|---------|-------|
| Firebase Auth | Email/password sign-in, Google Sign-In, email verification, password reset, account deletion |
| Firebase Core | App initialization (`firebase_options.dart`) |

---

### 8. Open-Meteo Weather API

Free, no-key weather API. The `WeatherService` resolves city coordinates via **Nominatim** (OpenStreetMap geocoding) then fetches current conditions from Open-Meteo. Displayed as a weather chip on the Home screen.

---

### 9. Photo Resolution Pipeline

`GooglePlacesPhotoService` resolves POI photos through a three-tier fallback:

1. Google Places photo URL
2. Wikipedia page image
3. Unsplash placeholder

Photos are cached in a `Map<String, String?>` keyed by `name_lat_lon` and injected into saved trips before upload.

---

## Flutter App Structure

```
lib/
├── main.dart                        # App entry, Firebase init, Mapbox token, navigation state
├── firebase_options.dart            # Auto-generated Firebase config
├── theme.dart                       # AppColors, typography, shared styles
│
├── models/
│   ├── user.dart                    # AppUser wrapper for Firebase user
│   ├── user_preferences.dart        # Trip preferences + toApiRequest()
│   ├── poi.dart                     # Point of Interest from recommendation API
│   ├── itinerary_event.dart         # Scheduled slot: POI + times + travel + reason
│   ├── itinerary.dart               # Full itinerary with day map + summary stats
│   ├── tourist_attraction.dart      # Google Places–backed attraction for the map
│   └── event.dart                   # Tazkarti event card
│
├── services/
│   ├── server_config.dart           # Recommendation API URL (AWS EC2)
│   ├── server_config_tazkarti.dart  # Tazkarti Vercel backend URL
│   ├── server_warmer.dart           # Periodic /health ping to prevent cold starts
│   ├── server_discovery.dart        # LAN discovery (localhost / subnet scan on port 8000)
│   ├── recommendation_api.dart      # POST /recommend + GET /health client
│   ├── auth_service.dart            # Firebase Auth operations
│   ├── guest_mode_service.dart      # SharedPreferences guest flag
│   ├── onboarding_service.dart      # Persists onboarding completion
│   ├── tazkarti_service.dart        # Fetch music events from Vercel proxy
│   ├── trip_storage_service.dart    # Save/fetch/delete trips on Vercel backend
│   ├── places_service.dart          # Google Places with 24h local cache
│   ├── google_places_photo_service.dart  # Photo resolution pipeline
│   ├── directions_service.dart      # Google Directions + polyline decode
│   ├── navigation_sdk_service.dart  # Google Routes API (traffic-aware)
│   ├── distance_matrix_service.dart # Batch Distance Matrix + Haversine pre-filter
│   ├── location_service.dart        # Geolocation + Street View
│   └── weather_service.dart         # Open-Meteo + Nominatim
│
└── screens/
    ├── splash_screen.dart
    ├── onboarding_screen.dart
    ├── welcome_screen.dart
    ├── login_screen.dart
    ├── signup_screen.dart
    ├── home_screen.dart
    ├── preference_setup_screen.dart
    ├── trip_generation_screen.dart
    ├── loading_screen.dart
    ├── trips_screen.dart
    ├── itinerary_screen.dart
    ├── my_trips_screen.dart
    ├── map_screen.dart
    ├── place_detail_screen.dart
    ├── profile_screen.dart
    ├── all_events_screen.dart
    └── who_am_i_screen.dart         # CV artifact identification
```

---

## Screens

### Navigation Flow

```
Splash → Onboarding (first run)
       → Welcome → Login / Sign Up
                 → Home (guest or signed in)
                      ├── Who Am I? (artifact scanner)
                      ├── Events → All Events
                      └── Generate Trip → Preferences → Loading → Itinerary Tab
                                                                 └── Place Detail

Bottom Nav: Home | Trips (Current + History) | Map | Profile
```

---

### Screen Descriptions

#### `SplashScreen`
Branded animated splash. `AppNavigator` evaluates Firebase user state, guest flag, and onboarding status to route to the correct first screen.

#### `OnboardingScreen`
Multi-page first-run introduction to the app's features. Completion is persisted via `OnboardingService`.

#### `WelcomeScreen`
Entry point offering **Sign In**, **Create Account**, or **Continue as Guest** paths.

#### `LoginScreen`
Email/password login and Google Sign-In via `AuthService`. Includes form validation and error handling.

#### `SignupScreen`
Registration form with terms acceptance. Sends email verification on success.

#### `HomeScreen`
Central hub of the app. Contains:
- Live **weather chip** for the selected city (Open-Meteo)
- **Tazkarti music events** carousel (fetched from Vercel proxy)
- **"Who Am I?"** entry point — launches the CV artifact scanner
- **Generate Trip** CTA that navigates to the preference wizard

#### `PreferenceSetupScreen`
6-step wizard that collects:
1. City (Cairo, Luxor, Aswan, Alexandria, Hurghada, Sharm El-Sheikh)
2. Trip duration (1–7 days)
3. Budget tier (Budget ~1,500 EGP/day · Moderate ~3,500 · Luxury ~10,000)
4. Interest categories with drag-to-reorder priority
5. Travel pace (Relaxed / Moderate / Fast)
6. Optional specific interest text

Builds a `UserPreferences` object that maps to the API request format.

#### `TripGenerationScreen`
Displays a summary of chosen preferences and calls `RecommendationApi.generateItinerary()`. Handles 503 (server initializing), timeout (2 min limit), and network errors.

#### `LoadingScreen`
~4.5s animated loading screen with Egyptian pyramid animation shown while the itinerary is being processed. Navigates automatically to the Itinerary tab on completion.

#### `TripsScreen`
Shell screen with two tabs:
- **Current Trip** → `ItineraryScreen`
- **History** → `MyTripsScreen`

#### `ItineraryScreen`
Renders the AI-generated day-by-day itinerary:
- Expandable day cards with time slots
- POI photos resolved via `GooglePlacesPhotoService`
- Auto-saves the trip to the Vercel backend when not in history mode
- Gemini recommendation text display per POI

#### `MyTripsScreen`
Lists all trips saved to the Vercel backend for the current user (keyed by Firebase UID). Tapping a trip loads it into the itinerary view.

#### `MapScreen`
Full-screen **Mapbox** map showing:
- Nearby tourist attractions via `PlacesService` (24h cache)
- Marker clustering
- Directions bottom sheet (Google Directions API + polyline rendering)
- User location tracking

#### `PlaceDetailScreen`
Detailed view of a POI from an itinerary event. Shows photos (via `GooglePlacesPhotoService`), description, times, cost, and travel information.

#### `ProfileScreen`
User profile management: display name, email verification status, change password, sign out, and delete account.

#### `AllEventsScreen`
Full scrollable list of Tazkarti music events. Each card links to the event page on tazkarti.com via `url_launcher`.

#### `WhoAmIScreen` — CV Artifact Identifier
See the [dedicated section](#cv-feature--who-am-i) below.

---

## Services

| Service | Description |
|---------|-------------|
| `ServerConfig` | Returns the AWS EC2 base URL for the recommendation API |
| `ServerConfigTazkarti` | Returns the Vercel base URL for Tazkarti events |
| `ServerWarmer` | Fires `GET /health` every 10 minutes on app start to keep the EC2 backend warm |
| `ServerDiscovery` | LAN discovery fallback: tries localhost, emulator bridge, then subnet scan on port 8000 |
| `RecommendationApi` | HTTP client for `/recommend` (POST) and `/health` (GET); 120s timeout; typed `RecommendationApiException` |
| `AuthService` | Firebase Auth: email/password, Google Sign-In, profile update, email verification, password reset, account deletion |
| `GuestModeService` | Reads/writes `SharedPreferences` guest flag |
| `OnboardingService` | Reads/writes `SharedPreferences` onboarding completion flag |
| `TazkartiService` | Fetches music events from Vercel proxy; parses `Event` list |
| `TripStorageService` | Save/fetch/delete `Itinerary` objects on Vercel backend; injects cached photo URLs before saving |
| `PlacesService` | Google Places Nearby Search + Details; Egyptian city coordinates; 24h local attraction cache |
| `GooglePlacesPhotoService` | Three-tier photo resolution: Google Places → Wikipedia → Unsplash placeholder |
| `DirectionsService` | Google Directions API; polyline decoding for Mapbox overlay |
| `NavigationSdkService` | Google Routes API `computeRoutes` for traffic-aware alternatives |
| `DistanceMatrixService` | Batched Distance Matrix requests (max 25 per batch); Haversine pre-filter to skip distant pairs |
| `LocationService` | Google Geolocation API + Street View URL builder and metadata |
| `WeatherService` | Nominatim geocode → Open-Meteo current conditions; displayed on Home as weather chip |

---

## Data Models

### `UserPreferences`
Holds all trip configuration collected in the 6-step wizard.

| Field | Type | Notes |
|-------|------|-------|
| `city` | String | Selected Egyptian city |
| `duration` | int | Trip length in days |
| `budget` | String | `budget` / `moderate` / `luxury` |
| `interests` | List\<String\> | Ordered by priority (index 0 = highest weight) |
| `pace` | String | `relaxed` / `moderate` / `fast` |
| `specificInterest` | String? | Optional free-text for refinement |
| `latitude` / `longitude` | double | City center coordinates for geo-aware ranking |

`toApiRequest()` converts this into the JSON body expected by `/recommend`.

---

### `Itinerary`
Top-level response from the recommendation API.

| Field | Notes |
|-------|-------|
| `itinerary` | Map of day keys → list of `ItineraryEvent` |
| `totalDays` | Number of days |
| `totalPois` | Total attractions |
| `estimatedCost` | Total estimated budget |
| `city` | Target city |

`fromJson()` handles both map and list formats for the `itinerary` field.

---

### `ItineraryEvent`
One time-slot entry within a day.

| Field | Notes |
|-------|-------|
| `poi` | `Poi` object (name, category, description, cost, lat/lon, duration) |
| `startTime` / `endTime` | Scheduled times |
| `travelTime` | Travel minutes from previous stop |
| `reason` | AI-generated reason for including this POI |

---

### `Poi`
A point of interest as returned by the recommendation engine.

| Field | Notes |
|-------|-------|
| `name` | Attraction name |
| `category` | Interest category (History, Food, etc.) |
| `description` | Short description |
| `cost` | Estimated entry/activity cost in EGP |
| `lat` / `lon` | Coordinates |
| `duration` | Typical visit duration in minutes |
| `photoUrl` | Optional photo URL injected before saving |

---

### `TouristAttraction`
Google Places–backed attraction used exclusively by the Map screen.

---

### `Event`
Tazkarti event card model.

| Field | Notes |
|-------|-------|
| `id` | Tazkarti event ID |
| `title` | Event name |
| `imageUrl` | Cover image |
| `date` | Event date string |
| `venue` | Location/venue name |

---

### `AppUser`
Thin wrapper around a Firebase `User` exposing `uid`, `email`, `displayName`, `isEmailVerified`.

---

## CV Feature — "Who Am I?"

`lib/screens/who_am_i_screen.dart`

### Purpose
Lets users point their camera (or pick from gallery) at an Egyptian artifact, mummy, or monument and get an AI identification with a historical description.

### Flow

```
Idle → Pick image (camera or gallery)
     → Image Preview → Tap "Identify Artifact"
     → POST multipart to Hugging Face Space /predict (60s timeout)
     → Recognized?
         Yes → Show artifact name (gold shimmer) + Historical Chronicle card
         No  → "Not Recognized" error state
```

### UI States

| State | Description |
|-------|-------------|
| `idle` | Eye of Ra animation + camera/gallery buttons + supported artifacts hint |
| `imageSelected` | Image preview + "Identify Artifact" button |
| `loading` | Scan-line animation overlay + "Consulting the Oracle..." text |
| `result` | Artifact name with animated gold shimmer + historical description card |
| `error` | "Not Recognized" with retry button |

### Visual Design
- Deep teal-black background (`#0D2733`) with animated particle system (40 gold particles)
- Eye of Ra (`𓂀`) hero icon with dual counter-rotating rings
- Backdrop blur (glassmorphism) on cards
- Scanning corner brackets during analysis
- Result name rendered with animated gold shimmer shader

### API Contract

**Request:**
```
POST https://abraam-refaat-egypt-artifact-api.hf.space/predict
Content-Type: multipart/form-data
Body: file=<image file (JPEG or PNG)>
```

**Response (recognized):**
```json
{
  "recognized": true,
  "character": "Tutankhamun",
  "brief": "Tutankhamun was an ancient Egyptian pharaoh...",
  "confidence": 0.94
}
```

**Response (not recognized):**
```json
{
  "recognized": false
}
```

### Supported Artifacts
Tutankhamun · Nefertiti · Great Sphinx · Egyptian monuments · Mummies and pharaonic figures

---

## AI Recommendation Engine

Previously hosted on Railway, now deployed on **AWS EC2**.

### Stack
- **FastAPI** — REST API server
- **SentenceTransformers** — semantic embeddings for interest → POI matching
- **CrossEncoder** — re-ranking of candidate POIs for relevance
- **pandas** — POI database (Excel / CSV, 150+ Egyptian attractions)
- **scikit-learn** — scoring utilities
- **PyTorch** — deep learning backend for transformer models

### How it works

```
User Preferences (JSON)
        │
        ▼
Semantic Query Generation
  (interests → text query)
        │
        ▼
SentenceTransformer Embeddings
  (query + all POI descriptions)
        │
        ▼
Cosine Similarity Candidate Retrieval
        │
        ▼
CrossEncoder Re-ranking
        │
        ▼
Multi-factor Scoring
  ├── Interest category match + priority weight
  ├── Budget constraint filter
  ├── Travel pace → max POIs/day
  ├── Distance from previous stop
  └── Diversity (avoid same-category clustering)
        │
        ▼
Route Optimization
  (greedy nearest-neighbor with time windows)
        │
        ▼
Day-by-day Itinerary JSON
```

### Cold Start
The `ServerWarmer` service pings `GET /health` every 10 minutes while the app is open to prevent the EC2 instance from sleeping.

### First Request Latency
Initial generation (cold model load) can take **30–60 seconds**. Subsequent requests complete in **5–15 seconds**.

---

## Dependencies

### Flutter / Dart

| Package | Purpose |
|---------|---------|
| `google_fonts` | Playfair Display (headings) + Inter (body) |
| `flutter_svg` | SVG image rendering |
| `http` | HTTP client for all REST calls |
| `http_parser` | MIME type handling for multipart uploads |
| `shared_preferences` | Local key-value persistence (guest flag, onboarding, server cache) |
| `network_info_plus` | Wi-Fi network info for LAN server discovery |
| `udp` | UDP broadcast for LAN server discovery |
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Authentication |
| `google_sign_in` | Google OAuth |
| `mapbox_maps_flutter` | Interactive map rendering |
| `google_places_flutter` | Google Places autocomplete widget |
| `dio` | Alternative HTTP client (used in Places service) |
| `cached_network_image` | Disk-cached remote image loading |
| `flutter_map_marker_cluster` | Map marker clustering |
| `latlong2` | Lat/lon coordinate type |
| `geolocator` | Device GPS location |
| `geocoding` | Address → coordinates conversion |
| `permission_handler` | Runtime permission requests |
| `flutter_polyline_points` | Google encoded polyline decoder |
| `url_launcher` | Open URLs in browser / deep links |
| `image_picker` | Camera and gallery photo selection |

### Dev Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_lints` | Dart lint rules |
| `flutter_launcher_icons` | Generate app icons from `assets/images/nile_quest_logo.png` |
| `flutter_native_splash` | Native splash screen (color `#1F4E5F`) |

---

## Configuration Notes

### Updating the Recommendation Server URL (AWS EC2)

Open `lib/services/server_config.dart` and replace the URL:

```dart
static String _getDefaultUrl() {
  return 'https://YOUR-EC2-PUBLIC-IP-OR-DOMAIN';
}
```

Also update the log message on line 10 to remove the stale "Railway" reference.

### Physical Device Testing

When running on a physical Android device, the recommendation API on localhost is unreachable. Use the EC2 URL (already configured) or switch `ServerConfig` to the local network IP of your development machine and start the Python backend locally.

### Android Build Requirements

| Setting | Value |
|---------|-------|
| `compileSdk` | 36 |
| `targetSdk` | 36 |
| `minSdk` | 21 |
| Android Gradle Plugin | 8.7.0 |
| Kotlin | 2.0.0 |

### API Keys Required

| Key | Where to set |
|-----|-------------|
| Mapbox Access Token | `lib/main.dart` → `MapboxOptions.setAccessToken(...)` |
| Google Maps / Places API Key | `android/app/src/main/AndroidManifest.xml` meta-data |
| Firebase Config | `lib/firebase_options.dart` (auto-generated by FlutterFire CLI) |
| Google Services JSON | `android/app/google-services.json` |
