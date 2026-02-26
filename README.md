# Nile Quest - AI-Powered Travel Planner 🏺

Discover the Magic of Egypt - A beautiful Flutter mobile application with **AI-powered personalized itinerary generation** for planning Egyptian travel adventures.

## ✨ Features

- 🎨 Beautiful UI with custom theme and animations
- 📱 Native mobile experience
- 🤖 **AI-Powered Recommendations** using SentenceTransformer + CrossEncoder
- 🗺️ **Smart Itinerary Generation** based on your interests, budget, and pace
- 🏛️ Personalized POI selection from 150+ attractions
- 📍 Intelligent routing to minimize travel time
- 💰 Real-time budget tracking
- ⏱️ Time-optimized daily schedules
- 💾 Save and share trips

## Screens

1. **Welcome Screen** - App introduction with login/guest options
2. **Login Screen** - User authentication with form validation
3. **Preference Setup** - 5-step wizard for trip preferences:
   - City selection
   - Trip duration
   - Budget selection
   - Interest categories
   - Travel pace
4. **Trip Generation** - Review preferences and generate trip
5. **Loading Screen** - Animated loading with Egyptian pyramid
6. **Itinerary Screen** - Daily schedule with expandable day cards
7. **Map Screen** - Visual map with location markers
8. **Place Detail Screen** - Detailed information about attractions
9. **Save Trip Screen** - Save trips and provide feedback

## 🚀 Quick Start

> **Important**: This app requires both the Flutter frontend AND the Python AI backend to function.

### Step 1: Start the AI Backend

**Windows**:
```bash
cd recommendation_model
start_api.bat
```

**macOS/Linux**:
```bash
cd recommendation_model
chmod +x start_api.sh
./start_api.sh
```

Wait until you see: `System initialized successfully!`

The API will be running at `http://localhost:8000`

### Step 2: Run the Flutter App

In a **new terminal**:

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

### 📖 Detailed Setup Guide

For comprehensive setup instructions, troubleshooting, and API configuration, see:

👉 **[SETUP_GUIDE.md](SETUP_GUIDE.md)**

## 🏗️ Architecture

```
┌─────────────────┐
│  Flutter App    │ ← User Interface
│  (Mobile)       │
└────────┬────────┘
         │ HTTP/REST
         │
┌────────▼────────────────────────┐
│  FastAPI Backend                │
│  - Recommendation Engine        │
│  - AI Models (SentenceTransf.)  │
│  - POI Database (Excel)         │
└─────────────────────────────────┘
```

## 🤖 AI Technology

The app uses cutting-edge AI for personalized recommendations:

1. **Semantic Search**: Converts your interests into AI embeddings
2. **CrossEncoder Re-ranking**: Re-ranks results for maximum relevance
3. **Smart Scoring**: Balances interests, budget, pace, and diversity
4. **Route Optimization**: Minimizes travel time between POIs
5. **Time Management**: Fits activities within your daily time window

### Prerequisites

**For Frontend**:
- Flutter SDK 3.0.0+
- Android Studio or Xcode
- Dart SDK (included with Flutter)

**For Backend**:
- Python 3.8+
- 2GB+ RAM (for AI models)
- pip (Python package installer)

## 📁 Project Structure

```
mobile-flutter/
├── lib/
│   ├── main.dart                     # App entry point and navigation
│   ├── theme.dart                    # App theme and colors
│   ├── models/                       # Data models
│   │   ├── poi.dart                 # POI (Place of Interest)
│   │   ├── itinerary.dart           # Itinerary structure
│   │   ├── itinerary_event.dart     # Event in itinerary
│   │   └── user_preferences.dart    # User preference data
│   ├── services/                     # API integration
│   │   └── recommendation_api.dart  # Backend API client
│   ├── screens/                      # All app screens
│   │   ├── welcome_screen.dart
│   │   ├── login_screen.dart
│   │   ├── preference_setup_screen.dart  # 5-step wizard
│   │   ├── trip_generation_screen.dart   # Calls AI API
│   │   ├── loading_screen.dart
│   │   ├── itinerary_screen.dart         # Shows AI results
│   │   ├── map_screen.dart
│   │   └── place_detail_screen.dart
│   └── widgets/                      # Reusable widgets
│       └── bottom_nav.dart
├── recommendation_model/             # Python AI Backend
│   ├── api_server.py                # FastAPI server
│   ├── tourist_recommendation_system.py  # Main AI engine
│   ├── ai_candidate_generator.py    # Semantic search
│   ├── requirements.txt             # Python dependencies
│   ├── start_api.bat               # Windows startup script
│   └── start_api.sh                # macOS/Linux startup script
├── assets/
│   └── images/                      # App images and logos
├── SETUP_GUIDE.md                   # Comprehensive setup instructions
├── pubspec.yaml                     # Flutter dependencies
└── README.md
```

## 📦 Dependencies

**Flutter/Dart**:
- **google_fonts**: Custom fonts (Playfair Display, Inter)
- **flutter_svg**: SVG image support
- **http**: REST API communication
- **cupertino_icons**: iOS-style icons

**Python/AI Backend**:
- **fastapi**: Modern web framework for APIs
- **sentence-transformers**: Semantic search AI models
- **pandas**: Data manipulation
- **scikit-learn**: ML utilities
- **torch**: Deep learning backend

## Color Palette

- **Primary**: Deep Teal (#1F4E5F)
- **Secondary**: Sandy Gold (#D4AF7A)
- **Accent**: Warm Orange (#E67E22)
- **Cream**: Warm Off-White (#F5F1E8)
- **Charcoal**: Dark Gray-Blue (#2C3E50)

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## 🎯 How It Works

1. **User Input**: Select city, duration, budget, interests (prioritized), and pace
2. **API Call**: Flutter app sends preferences to Python backend via REST API
3. **AI Processing**:
   - Converts interests to semantic query
   - Searches 150+ POIs using AI embeddings
   - Scores and ranks based on your preferences
   - Optimizes for diversity, distance, time, and budget
4. **Itinerary Generation**: Returns personalized day-by-day schedule
5. **Display**: Flutter app renders your custom itinerary with times and costs

## 🌟 Interest Categories

- **History**: Museums, archaeological sites, monuments
- **Food**: Restaurants, cafes, traditional cuisine
- **Nature**: Parks, gardens, scenic spots
- **Shopping**: Markets, bazaars, shops
- **Entertainment**: Shows, activities, nightlife
- **Religious**: Mosques, churches, temples

## 💡 Tips

- **First Run**: AI model initialization takes 2-5 minutes on first API start
- **Physical Devices**: Update API endpoint in `lib/services/recommendation_api.dart` to your computer's local IP
- **Interest Priority**: Drag interests to reorder - first gets highest weight!
- **Budget Tiers**: 
  - Budget: ~1500 EGP/day
  - Moderate: ~3500 EGP/day  
  - Luxury: ~10000 EGP/day

## 🐛 Troubleshooting

- **Can't connect**: Make sure Python API is running (`python api_server.py`)
- **Timeout**: First generation can take 30-60 seconds
- **503 Error**: API still initializing, wait a few seconds
- See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed troubleshooting

## 📱 Demo Flow

1. Welcome → Continue as Guest
2. Preferences: Cairo, 3 days, Moderate, [History, Food], Moderate pace
3. Tap "Generate My Trip"
4. Wait 10-30 seconds
5. View personalized itinerary!

## 🚀 Future Enhancements

- [ ] Multiple cities in one trip
- [ ] Weather integration
- [ ] Real photos from Google Places API
- [ ] User accounts and trip history
- [ ] Share itineraries with friends
- [ ] Cloud deployment of AI backend

## 📄 License

Educational and demonstration purposes.

---

**Version**: 1.0.0  
**Built with**: Flutter, FastAPI, SentenceTransformers  
**AI Models**: all-MiniLM-L6-v2, ms-marco-MiniLM-L-6-v2
