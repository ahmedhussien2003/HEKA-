# Heka (هيكا) - Prototype Info & Features Documentation

Welcome to **Heka**, an advanced mobile and multi-platform application designed for **Ancient Egyptian Hieroglyphics Detection, Translation, and Augmented Reality (AR) Exploration**.

This document serves as the comprehensive **Prototype Information** manual, detailing all **Functional** and **Non-Functional** features implemented in the Heka application codebase.

---

## 📱 Executive Overview

| Attribute | Details |
| :--- | :--- |
| **Application Name** | Heka (هيكا) |
| **Domain** | Egyptology, Computer Vision, Artificial Intelligence, Augmented Reality |
| **Frontend Framework** | Flutter 3.x (Dart) |
| **Backend & Cloud** | Firebase Authentication, Cloud Firestore Database |
| **AI / ML Infrastructure** | Python (FastAPI / REST backend), PyTorch, TensorFlow / Keras |
| **Computer Vision Models** | ConvNeXt, EfficientNet, SAM (Segment Anything Model), CtrlF Segmentation |
| **NLP Transformer Models** | BART, BERT, Custom Hieroglyphic Sentence Composition Engine |
| **Supported Languages** | 7 UI & Translation Languages (English, Arabic, Italian, German, Spanish, Russian, Polish) |

---

## ⚡ 1. Functional Features (الوظائف الوظيفية)

### 🔑 1.1 Authentication & User Management
* **Email & Password Authentication**:
  * User Registration collecting First Name, Last Name, Email, Password, Birth Date, and Phone Number.
  * Secure Sign-In with validation and error handling (e.g., weak passwords, existing emails).
* **Google OAuth Sign-In Integration**:
  * One-tap authentication using Google accounts via `google_sign_in`.
  * Dedicated onboarding completion flow (`GoogleSignupPage`) for new Google users to fill missing profile information (Phone Number, Birth Date).
* **Persistent Session Management**:
  * Automated login state listening via `AuthGate` / `WidgetTree` to preserve user sessions across application restarts.
* **Profile Management & Analytics**:
  * View user profile details with custom avatar presentation.
  * Real-time metrics counters tracking **Total Translations** and **Saved Glyphs**.
  * Edit user details (`EditProfilePage`) updating Cloud Firestore synchronously.
* **Account Deletion & Data Cleanup**:
  * Complete user account deletion support, purging user credentials and performing batch deletion of stored subcollection data (`users/{uid}/Translation data`).
  * Account data migration (`cloneUserData`) capability for account restructuring.

---

### 🔤 1.2 Single Symbol Detection & Translation ("One Symbol Mode")
* **Image Acquisition**:
  * Take live photographs using the device camera.
  * Import high-resolution images from the photo gallery via `image_picker`.
* **Interactive Image Cropping**:
  * Built-in cropping tool (`image_cropper`) allowing users to isolate individual hieroglyphic symbols prior to classification.
* **AI Hieroglyphic Classification**:
  * Real-time submission of single symbol cropped images to the deep learning REST API endpoint (`/predict`).
  * Classification matching against **67+ Gardiner categories** (e.g., A1, G43, N35, etc.).
* **Comprehensive Symbol Metadata Output**:
  * **Gardiner Code**: Universal Egyptian Hieroglyphic Classification identifier.
  * **Multilingual Meaning**: Meaning in English and target selected language (e.g., Arabic, German, etc.).
  * **Phonetics & Transliteration**: Accurate phonetic pronunciation guide.
  * **Category & Description**: Symbol classification (e.g., Birds, Mammals, Gods, Tools).
  * **Confidence Score & API Time**: Displays detection confidence percentage and backend execution duration.
* **Interactive Symbol Details Sheet**:
  * Modal bottom sheet presenting rich historical context, phonetics, and grammatical function of the detected sign.
* **Save & Bookmark**:
  * Save symbol detection results to Cloud Firestore history with real-time UI state toggle (`_isSaved`).
* **Instant AR Transition**:
  * One-click navigation button to launch the AR Explorer pre-loaded with the identified symbol.

---

### 📜 1.3 Multi-Symbol & Inscription Translation ("Many Symbols Mode")
* **Inscription Image Scanning**:
  * Capture or upload complex ancient Egyptian stelae, wall reliefs, papyri, or tomb inscriptions containing multiple hieroglyphs.
* **Automated Multi-Symbol Segmentation**:
  * Integration with **SAM (Segment Anything Model)** and **CtrlF Segmentation** algorithms to automatically detect, bound, and crop individual glyphs within a single image.
* **Hieroglyphic Sequence to Natural Sentence AI Translation**:
  * Multi-symbol Gardiner sequence passed to fine-tuned **BART / BERT Transformer NLP models** (`model_NLP.py`, `model_LLM.py`).
  * Context-aware sentence synthesis converting hieroglyphic word order into grammatical, natural sentences.
* **Simultaneous Multilingual Sentence Output**:
  * Generates translations in all 7 supported target languages:
    * 🇬🇧 **English**
    * 🇪🇬 **Arabic (العربية)**
    * 🇮🇹 **Italian (Italiano)**
    * 🇩🇪 **German (Deutsch)**
    * 🇪🇸 **Spanish (Español)**
    * 🇷🇺 **Russian (Русский)**
    * 🇵🇱 **Polish (Polski)**
* **Gardiner Breakdown Grid**:
  * Interactive grid listing every detected individual symbol in sequential order with its respective Gardiner code and individual word translation.
* **Translation Persistence**:
  * Record full multi-symbol translation runs to Cloud Firestore (`recordTranslation`).

---

### 🥽 1.4 Augmented Reality (AR) Interactive Explorer ("AR Mode")
* **Live Camera Viewfinder**:
  * Full-screen camera interface featuring custom animated targeting reticles, HUD elements, and scanning laser lines.
* **Sensor-Assisted Motion & Parallax Effects**:
  * Utilizes device accelerometer and gyroscope sensors via `sensors_plus` to create real-time depth and 3D parallax floating effects on visual overlays.
* **Animated 3D Visual Cards**:
  * Custom rendering engine powered by Flutter animation controllers (`_floatController`, `_shimmerController`, `_pulseController`, `_revealController`).
  * Displays floating hieroglyphic cards over real-world artifacts with shimmering gold borders, floating bob animations, and glowing effects.
* **In-Situ Inscription Projection**:
  * Projects translated natural sentences and Gardiner breakdown directly onto physical museum artifacts and monuments in real-time.
* **Direct AR Capture**:
  * Option to capture photo directly within AR mode and run immediate live inference.

---

### 🕒 1.5 Translation History & Saved Library
* **Real-Time History Stream**:
  * Cloud Firestore live stream (`getTranslationHistory`) listing all previous user translations ordered by timestamp descending.
* **Detailed Record Cards**:
  * Previews thumbnail images, mode indicator (Single Symbol vs Multi-Symbol), original Gardiner codes, translated text in the active language, and timestamp format via `intl`.
* **Saved Glyphs Library**:
  * Quick-access bookmark tab for favorited hieroglyphics and important translated inscriptions.
* **History Record Management**:
  * Option to delete individual history entries, automatically decrementing user statistics counters.

---

### 🌍 1.6 Localization & Multi-Language UI (i18n)
* **7 Comprehensive UI Languages**:
  * Full localization of all UI titles, buttons, dialogs, error messages, and descriptions in Arabic, English, Italian, German, Spanish, Russian, and Polish.
* **Instant Dynamic Language Switcher**:
  * Real-time application-wide language change without app restart using `selectedLanguageNotifier` and `AppTranslations`.
* **Dual Bilingual Display Toggle**:
  * Toggle switch (`showArabicEnglishNotifier`) allowing simultaneous viewing of primary translations alongside Arabic/English reference text.
* **Persistent Preference Saving**:
  * User preferred language automatically synchronized with Firestore (`saveUserLanguage`).

---

### ⚙️ 1.7 Application Settings & Preferences
* **Theme Switching (Light Mode / Dark Mode)**:
  * Dynamic theme switching using `isDarkModeNotifier`.
  * Customized dark and light palettes styled around ancient Egyptian temple aesthetics (`Temple_Gold`, `Temple_Background_Dark`, `Temple_Card_Dark`, etc.).
* **App Information Pages**:
  * **About Us Page**: Project background, mission statement, team presentation, and Egyptological vision.
  * **FAQs Page**: Interactive collapsible accordion detailing common questions regarding hieroglyphic translation accuracy, model limits, and app usage.
  * **Privacy Policy Page**: Clear disclosure of data privacy rules, storage security, and image usage.
* **Session Termination**:
  * Clean log-out mechanism clearing session tokens and returning to `LoginPage`.

---

## 🛠️ 2. Non-Functional Features (الوظائف غير الوظيفية)

### 🏎️ 2.1 Performance & Latency
* **Asynchronous Network Architecture**:
  * High-performance HTTP client powered by `dio` featuring configurable connection (`30s`) and send/receive (`3-60 min`) timeouts optimized for complex deep learning model inference.
* **Client-Side Image Optimization**:
  * Automated image downscaling (`maxWidth: 1024`, `imageQuality: 70`) prior to backend transmission, significantly reducing bandwidth consumption and API response latency.
* **Reactive & Granular State Management**:
  * Usage of Flutter `ValueNotifier` and `ValueListenableBuilder` to isolate widget rebuilds, maintaining 60 FPS performance without heavyweight global state re-renders.
* **Hardware-Accelerated Render Pipeline**:
  * Smooth native animations rendered via Flutter GPU canvas using `TickerProviderStateMixin`, Lottie animation vectors, and custom painters.

---

### 🔒 2.2 Security & Data Integrity
* **Tokenized Authentication**:
  * Firebase Authentication handles user credential encryption, token refresh, and session management. User passwords are **never** stored in plain text or secondary databases.
* **Granular Database Security Rules**:
  * Firestore rules (`firestore.rules`) enforce user isolation, ensuring users can only read, update, or delete data stored under their own unique identifier (`request.auth.uid == userId`).
* **Environment Base URL Configuration**:
  * Secure API endpoint management via `--dart-define=API_BASE_URL=...`, isolating development, staging, and production server infrastructure.

---

### 🎨 2.3 Usability & Design Aesthetics
* **Ancient Egyptian Visual Theme System**:
  * Curated color system featuring Ancient Gold (`#D4AF37`), Dark Temple Stone, Hieroglyphic Parchment, and vibrant accents.
* **Custom Typography**:
  * Elegant font system utilizing `JosefinSans` paired with fallback fonts like `ReemKufi` for optimal rendering of Latin, Cyrillic, and Arabic script.
* **Responsive Layout Design**:
  * Dynamic screen dimension calculations (`MediaQuery`, `.clamp()`) ensuring flawless layout adaptation across compact smartphones, tablets, foldables, and desktop/web viewports.
* **Tactile Feedback & Visual Polish**:
  * Shimmer loading skeletons, glowing aura animation effects, clear error notifications, and intuitive modal dialogs.

---

### 🏗️ 2.4 Architecture & Scalability
* **Separation of Concerns**:
  * Clean directory structure dividing data models (`lib/data`), services (`lib/services`), UI pages (`lib/views/pages`), widgets (`lib/views/widgets`), and ML scripts (`lib/translation_model`).
* **Decoupled AI Engine Microservices**:
  * Heavy neural network weights (ConvNeXt ~1.7GB, SAM, EfficientNet, BART, BERT) hosted on Python REST microservices, keeping the Flutter client application size minimal and fast to install.
* **Cross-Platform Compatibility**:
  * Built using Flutter SDK supporting Android, iOS, Web, Windows, macOS, and Linux targets.

---

### 🔍 2.5 Maintainability & Observability
* **Network Logging & Interceptor Diagnostics**:
  * Dio logging interceptor configured in debug mode to track HTTP request/response lifecycles, status codes, and error traces.
* **Centralized Translation Dictionary**:
  * Scalable translation repository (`lib/data/translations.dart`) enabling rapid addition of new international languages or terminology updates.
* **Robust Error Handling**:
  * Try-catch wrappers and user-friendly error fallback screens for network disconnections, invalid images, or server timeouts.

---

## 📐 Project Structure Matrix

```
lib/
├── data/
│   ├── notifiers.dart             # ValueNotifiers for theme, language, and navigation
│   └── translations.dart          # Multilingual UI string dictionary (7 languages)
├── services/
│   └── firestore_service.dart     # Cloud Firestore CRUD & User Management
├── translation_model/
│   ├── main_one_symbol.py         # Python FastAPI service for single-symbol AI
│   ├── main_multi_symbols.py      # Python FastAPI service for multi-symbol AI & SAM
│   ├── model_classification.py   # ConvNeXt / EfficientNet inference logic
│   ├── model_segmentation.py     # SAM & CtrlF image segmentation pipeline
│   └── model_NLP.py              # BART / BERT sentence generation engine
├── views/
│   ├── auth_gate.dart             # Firebase Auth state listener
│   ├── widget_tree.dart           # Main App scaffold with bottom navigation bar
│   ├── Headers/                   # Top app bar header components
│   ├── widgets/                   # Reusable UI widgets & cards
│   └── pages/
│       ├── home_page.dart         # Main Dashboard & Feature Gateway
│       ├── one_symbol_page.dart   # Single Symbol Detection & Details Page
│       ├── many_symbols_page.dart # Multi-Symbol Segmentation & Inscription Translation Page
│       ├── ar_page.dart           # Augmented Reality Camera Explorer & 3D Cards
│       ├── history_page.dart      # Real-time Translation History Stream
│       ├── saved_page.dart        # Saved Glyphs & Favorites Library
│       ├── profile_page.dart      # User Profile, Avatar & Activity Stats
│       ├── editProfile_page.dart  # Profile Edit Form
│       ├── setting_page.dart      # Language, Theme (Dark/Light) & App Preferences
│       ├── login_page.dart        # User Login Interface
│       ├── signup_page.dart       # User Registration Interface
│       ├── google_signup_page.dart# Google Sign-In Onboarding Completion Page
│       ├── about_us_page.dart     # Project Vision & Research Team Information
│       ├── faqs_page.dart         # Frequently Asked Questions Accordion
│       └── privacy_policy_page.dart # Privacy Terms & Guidelines
└── main.dart                      # Application Entry Point & Global Configuration
```

---

## 🚀 Getting Started & Setup

### Prerequisites
1. **Flutter SDK**: `^3.10.7` or higher.
2. **Dart SDK**: Compatible with Flutter SDK.
3. **Firebase Project**: Connected with `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
4. **Python ML Backend**: Python 3.9+ with PyTorch, TensorFlow, FastAPI, and required weight files (`best_ConvNext_model.keras`, SAM weights, BART/BERT JSON weights).

### Running the App
```bash
# 1. Fetch Flutter dependencies
flutter pub get

# 2. Run Python AI Backend Service (in background or separate terminal)
python lib/translation_model/main_multi_symbols.py

# 3. Launch Flutter Application
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

---

*Document compiled for Heka Ancient Egyptian Translation & AR Exploration Prototype.*
