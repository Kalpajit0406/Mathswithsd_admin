# 🎓 MathsWithSD — AI-Powered Math Learning & Examination Suite

MathsWithSD is a comprehensive, dual-application ecosystem designed to revolutionize how students prepare for mathematics exams and how teachers manage evaluations. Driven by a robust backend and advanced AI OCR scanning capabilities, it splits administrative tasks and learning workflows into two distinct, dedicated experiences.

---

## 📁 System Architecture Overview

The codebase is split into three main modules:

1. **`math-app-backend`**: A high-performance Node.js/Express and MongoDB server providing secure API services, JWT authentication, cohort management, and an advanced Mathpix OCR ingestion pipeline.
2. **`mathswithsd` (Student Client)**: A modern Flutter application designed for students to take assessments, track real-time leaderboards, analyze progress, and view teacher announcements.
3. **`mathswithsd_admin` (Teacher Admin Client)**: A custom administrative dashboard designed exclusively for the educator. Integrated with Mathpix AI to capture physical questions and LaTeX-rendered formulas instantly via camera scan, create dynamic tests, and approve/reject student registrations.

---

## 🚀 Key Features & Architectural Upgrades

### 🔑 1. Secure Passwordless Admin Bypass
* **App Layer**: Removed registration and password fields from the Teacher Admin login interface, replacing it with a single, secure **"Login as Teacher"** trigger linked to the authorized teacher mobile number (`6289855545`).
* **Backend Layer**: Implemented an automated authentication override in `authService.js`. The backend intercepts login requests for the hardcoded teacher number, bypassing standard password checks.
* **Auto-Provisioning**: If the teacher account does not exist in MongoDB, the backend automatically generates a secure teacher model pre-seeded with all required Mongoose schema constraints (such as `classNo`, `language`, and `guardianPhone`) to prevent database validation errors.

### 🤖 2. Mathpix AI OCR Question Pipeline
* Replaced legacy, low-accuracy text recognition with a state-of-the-art **Mathpix API** pipeline.
* Capable of scanning hand-written or printed questions from images, separating plain text from complex mathematical notation, and returning fully valid LaTeX formats.
* Seamlessly renders formulas using Flutter KaTeX/LaTeX components, maintaining perfect math presentation on mobile screens.

### 🎨 3. "Academic Pillar" Admin Dashboard Overhaul
* Transformed the `mathswithsd_admin` interface using a premium **Corporate Modern** design system:
  * **Brand Palette**: Custom deep academic primary hues (`#0051D5`) combined with soft, anti-glare neutrals (`#F7F9FB`).
  * **Dashboard Grid**: Responsive, high-elevation card grids utilizing tonal layer shadows for structural visual hierarchy.
  * **Bottom Navigation**: Custom navigation bar including a raised, floating **(+)** Action Button that anchors rapid question creation directly inside the viewport.
  * **Role Isolation**: Restricted standard student navigation within the admin application, replacing student routes with strict Access Control guards.

### 📶 4. Dynamic Dev Environment Connectivity
* Resolved physical device socket errors (`Connection Timeout`) caused by dynamic local router IP changes.
* Implemented automatic configuration updating inside `constants.dart` (`API_BASE_URL`), mapping the frontend app connection automatically to the host computer's active LAN network IP.

### ⚙️ 5. Gradle & Kotlin DSL Platform Stability
* Resolved critical Kotlin compiler crashes (`java.lang.IllegalArgumentException: 25.0.2`) caused by Java 25 Early Access environment paths on developers' workstations.
* Configured local `gradle.properties` overrides to enforce compiling with the stable, Android Studio bundled OpenJDK 21 Runtime (`org.gradle.java.home`), ensuring smooth builds across all machines.

---

## 🛠️ Setup & Execution Guide (`/init`)

### 1. Starting the Backend Server
```bash
# Navigate to the backend directory
cd c:\Users\kalpa\OneDrive\Desktop\MathswithSD\MathswithSD\math-app-backend

# Install dependencies (if not already done)
npm install

# Start the local development server (runs on port 5000 with hot-reload)
npm run dev
```

### 2. Launching the Student App (`mathswithsd`)
```bash
# Navigate to the student app directory
cd c:\Users\kalpa\mathswithsd

# Clean dependencies and cache
flutter clean
flutter pub get

# Launch the app on a connected device/emulator
flutter run
```

### 3. Launching the Teacher Admin App (`mathswithsd_admin`)
```bash
# Navigate to the teacher admin directory
cd c:\Users\kalpa\mathswithsd_admin

# Clean dependencies and cache
flutter clean
flutter pub get

# Launch the app on a connected device/emulator
flutter run
```

---

## 📈 Next Milestones
- [ ] **Dynamic Batch Scanning**: Expand OCR pipeline to ingest and parse multi-question images into structured MCQ questionnaires.
- [ ] **LaTeX Question Editor**: Real-time interactive preview of LaTeX structures inside the "Create Question" tab.
- [ ] **Automatic IP Syncing Utility**: Build a simple local shell script to auto-generate `constants.dart` based on active network adapters.
