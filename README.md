# 🎓 MathsWithSD — Teacher Admin Application

[![Flutter SDK](https://img.shields.io/badge/flutter-v3.0+-blue.svg)](https://flutter.dev/)
[![Dart Language](https://img.shields.io/badge/dart-%3E%3D%203.0-navy.svg)](https://dart.dev/)
[![Camera Scan API](https://img.shields.io/badge/camera-OCR-orange.svg)](#)
[![State Management](https://img.shields.io/badge/state--management-provider-green.svg)](https://pub.dev/packages/provider)

Welcome to the Teacher Admin application for **MathsWithSD**! This is a comprehensive dashboard designed exclusively for educators. Equipped with a camera-driven **Mathpix AI OCR** extraction pipeline, it enables teachers to scan printed or handwritten math questions from textbooks, automatically parse equations into valid LaTeX syntax, author exams, manage chapters, and approve student registration accounts.

---

## 🚀 Key Features

*   **AI OCR Math Camera**: Ingests math problems directly from the device's camera. The built-in Mathpix API extracts plaintext alongside complex math symbols and returns fully rendered LaTeX layouts.
*   **Curriculum & Chapter Manager**: Full CRUD workspace to define chapters with name normalization logic. Changes are cached and synchronized to the student clients automatically.
*   **Approval Queue for Registrations**: View pending student registration applications, verify details, and approve or deny accounts before they can access the exam suite.
*   **Flexible Assessment Compiler**: Select, filter, and assign questions from the question repository to build custom examinations. Control exam parameters like durations and target student cohorts.
*   **Interactive LaTeX Preview**: A specialized creator panel supporting live rendering of math models using `flutter_math_fork` to verify syntax before saving questions.
*   **Secure Passwordless Bypass**: Optimized login process with direct teacher authorization mapping to the designated teacher credentials.

---

## 🛠️ Technology Stack

*   **UI Framework**: Flutter SDK & Dart
*   **State Management**: Provider (v6.1.5)
*   **Routing & Navigation**: GoRouter (v17.3.0)
*   **Hardware Integration**: Flutter Camera SDK (v0.12.0+1) & Permission Handler
*   **Local Caching & Auth Storage**: Shared Preferences & Flutter Secure Storage
*   **Networking**: HTTP client mapping to backend API routes
*   **Mathematical Presentation**: flutter_math_fork (KaTeX compiler fork)

---

## 📁 Repository Structure

```
mathswithsd_admin/
├── android/                    # Android platform configurations
├── ios/                        # iOS platform configs and camera plist permissions
├── assets/
│   └── images/                 # Custom UI graphics and assets
├── lib/
│   ├── models/                 # Data schemas (Question, Exam, Student, Chapter)
│   ├── providers/              # State management classes (Auth, Question, Chapter, Student registration)
│   ├── screens/
│   │   ├── admin/              # Dashboard, Approvals, Chapter Manager, Exam Creator, OCR scanner
│   │   ├── shared/             # General templates, widgets, and LaTeX preview cells
│   │   └── login_screen.dart   # Secured passwordless bypass login interface
│   ├── services/               # REST API calls and Mathpix OCR extractor integrations
│   ├── utils/                  # Color configurations, constants, theme schemes
│   └── main.dart               # App entry and provider setup
├── pubspec.yaml                # Project metadata and package list
└── README.md                   # Administrative app guide
```

---

## ⚙️ Setup & Execution

### Prerequisites

*   **Flutter SDK**: `v3.0.0` or higher
*   **Dart SDK**: `v3.11.5` or higher
*   **Physical Mobile Device (Android/iOS)**: Necessary to test camera functionality (emulators might not fully support the camera framework)
*   **MathsWithSD Backend**: Active Node.js server configured with Mathpix developer credentials

### Running the Application

1.  **Navigate to Directory**:
    ```bash
    cd mathswithsd_admin
    ```

2.  **Configure API Endpoint**:
    Set the backend endpoint inside `lib/utils/constants.dart`. Set `API_BASE_URL` to the host computer's active local LAN IP (e.g. `http://192.168.1.50:5000/api/v1`).
    
    *Or run the root setup script `dev-setup.sh` which automatically updates the IP for you.*

3.  **Install Packages**:
    ```bash
    flutter pub get
    ```

4.  **Clean Build Cache**:
    ```bash
    flutter clean
    ```

5.  **Run the App**:
    Connect your mobile device and run:
    ```bash
    flutter run
    ```

---

## 👥 Credits

*   **Created by**: [Kalpajit](https://github.com)
*   **Inspired by**: [Debosmit](https://github.com), [Rupam](https://github.com)
*   **Special Thanks**: Soumen Sir, Swagata

---

## 📄 License

This repository is licensed under the [ISC License](LICENSE).
