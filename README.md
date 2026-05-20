# Ciro App: AI-Powered Weather & Crisis Alert System [⬇️ Latest Build](https://github.com/Talhakhalidawan/Ciroreleases/latest)

Ciro is an intelligent, real-time weather and crisis monitoring mobile application built with Flutter. It bridges the gap between traditional meteorological data and hyper-local, user-generated social media reports by utilizing a multi-agent AI workflow on the backend.

## 🏗️ System Architecture

The ecosystem consists of two primary components:
1. **Frontend (`Ciro-app`)**: This highly polished, offline-resilient Flutter application.
2. **Backend (`Ciro Django API`)**: A robust Django REST API that acts as an orchestrator for traditional weather APIs and the AI agents.

### The Application Workflow

1. **Zero-Latency Startup**: On launch, the Flutter app instantly loads cached weather and alert data from local storage (`SharedPreferences`). This ensures the user is never left staring at a blank loading screen, even without an internet connection.
2. **Smart Throttling & Syncing**: The app securely requests the backend for updates. To prevent rate-limiting and battery drain, the app enforces a strict 30-minute interval between background fetches. 
3. **Offline Resilience**: If the device is offline or the backend server is unreachable, the app enters a paused state gracefully. It displays a subtle offline icon (`cloud_off`) and periodically checks the connection in the background to automatically resume syncing when possible.
4. **Native Alerts**: When the backend detects a crisis, the Flutter app triggers native, color-coded Android Heads-Up notifications (e.g., Red for Wildfires, Blue for Floods) to ensure the user is warned immediately, even if the app is closed.

---

## 🔗 Backend Connections & Data Aggregation

When the mobile app makes a `POST` request to the backend's `/api/weather/` endpoint (sending the user's coordinates and time), the Django orchestrator aggregates data from multiple traditional sources:

*   **Open-Meteo**: For highly accurate temperature, wind, and precipitation forecasting.
*   **TomTom API**: For real-time traffic incident mapping.
*   **NASA FIRMS**: For satellite-detected active fire hotspots nearby.
*   **Air Quality APIs**: For local AQI measurements.

The backend structures this massive stream of data into a lean, mobile-friendly JSON object representing the current environmental snapshot.

---

## 🤖 Multi-Agent Crisis Detection Workflow

The true power of Ciro lies in its asynchronous, multi-agent AI workflow running on the backend. Traditional weather APIs can tell you it's hot, but they can't tell you if a wildfire has broken out nearby. Ciro solves this.

### Phase 1: Anomaly Detection & Query Generation
If the environmental snapshot reveals extreme conditions (e.g., extreme heat, heavy sudden rain, or high traffic incident counts), the first AI agent activates. It formulates highly targeted, localized search queries (e.g., *"Gujrat flash flood roads blocked"* or *"California active wildfire footage"*).

### Phase 2: Smart Platform Search
The system executes these queries across multiple platforms concurrently (X/Twitter, YouTube, TikTok, Reddit, and Facebook) to gather real-time, user-generated content, news snippets, and video descriptions from the ground.

### Phase 3: AI Analysis Agent (`analyze_with_ai`)
The raw data scraped from social media is massive and noisy. The analysis agent (powered by LLMs like Gemini or Groq) processes this data to:
1. **Filter Noise**: Remove fake news, clickbait, and irrelevant posts.
2. **Verify Authenticity**: Cross-reference multiple social posts against the environmental data to confirm an actual crisis is occurring.
3. **Determine Severity**: Classify the event (e.g., Wildfire, Flood, Storm) and assign a severity level.

### Phase 4: Alert Delivery
If the AI concludes a crisis is imminent or ongoing, it synthesizes a structured warning. This warning is injected into the weather response payload, passed back to this Flutter app, and blasted to the user via a high-priority push notification.

---

## 🚀 CI/CD & Deployment

This repository utilizes **GitHub Actions** for continuous integration.
*   Upon every push to the `main` or `master` branch, the `.github/workflows/release.yml` workflow triggers.
*   It sets up Java 17 and the Flutter SDK, fetches dependencies, and compiles a production-ready `app-release.apk`.
*   The generated APK is automatically attached to a new GitHub Release for easy download and testing.

---

## 📥 Download Latest Version

[⬇️ Download the latest highly-optimized APK release here](https://github.com/Talhakhalidawan/Ciroreleases/latest)

*(Note: Once uploaded to GitHub, replace `YOUR_USERNAME/YOUR_REPOSITORY` with your actual GitHub username and repository name in the link above)*
