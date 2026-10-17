# PDF Plagiarism Detection App 

A cross-platform Flutter application designed for educational institutions to detect document similarity, perform OCR text extraction, and analyze AI-generated content across single and batch PDF assignments.

---

##  Table of Contents

* [About the Project](https://www.google.com/search?q=%23-about-the-project)
* [Key Features](https://www.google.com/search?q=%23-key-features)
* [Tech Stack](https://www.google.com/search?q=%23-tech-stack)
* [System Architecture & Workflow](https://www.google.com/search?q=%23-system-architecture--workflow)
* [Project Directory Structure](https://www.google.com/search?q=%23-project-directory-structure)
* [Getting Started](https://www.google.com/search?q=%23-getting-started)
* [Testing & Quality Assurance](https://www.google.com/search?q=%23-testing--quality-assurance)
* [Limitations & Future Roadmap](https://www.google.com/search?q=%23-limitations--future-roadmap)


---

##  About the Project

**Pdf Plagiarism** (`pdf_plagiarism_app`) provides a multi-tiered pipeline for academic evaluation. Rather than relying solely on external web scrapers, the system reads native PDF text streams, performs image preprocessing with OCR on scanned documents, computes N-gram token overlaps, and checks for synthetic AI text writing patterns.

The application supports two user profiles:

* **Students:** Upload assignment PDFs, view color-coded match feedback, check overall similarity badges, and track submission history.


* **Admin Evaluators:** Configure evaluation thresholds, manage cohort batch comparisons, inspect cross-document similarity matrices, and export detailed reports.



It operates in both an **offline local mode** (using SQLite and SharedPreferences) and an **API-backed cloud mode** (via REST endpoints with token authentication).

---

##  Key Features

* **Multi-Format Text Ingestion & OCR:** Extracts text directly from vector PDF streams and applies Tesseract (`eng.traineddata`) or Vision OCR preprocessing to scanned pages.


* **N-Gram Similarity Engine:** Evaluates document overlap ranges using Jaccard/Cosine token similarity metrics and pinpoints exact character offset matches.


* **Dual-Layer AI Detection:** Analyzes linguistic perplexity heuristics and token distribution uniformity to estimate synthetic AI authorship likelihood.


* **Batch Processing Queue:** Runs background Dart isolates with reactive BLoC/Cubit state management (`BatchCubit`) to process multi-file cohorts without freezing the UI.


* **Side-by-Side Comparison Viewer:** Renders comparative views featuring color-coded match span highlighting and match threshold filters.


* **Cross-Platform Support:** Runs natively across Android, iOS, macOS, Windows, Linux, and Web.


* **Role-Based Access Control:** Role-restricted dashboards and screens tailored for Students and Admin Evaluators.


* **Report Exporting & Notifications:** Generates exportable summary reports and triggers real-time state alerts upon evaluation completion.



---

##  Tech Stack

| Layer | Technology | Purpose in Project |
| --- | --- | --- |
| **Frontend UI** | Flutter 3.x, Dart SDK | Reactive UI components, Material Design, custom UI Kit.

 |
| **State Management** | Flutter BLoC, Cubit | Handles `BatchCubit` processing queues, auth state, and notifications.

 |
| **OCR & Processing** | Tesseract OCR, Vision OCR, `pdf_service.dart` | Vector PDF stream parsing and scanned page OCR extraction.

 |
| **Similarity Engine** | N-Gram Engine, `ai_detection_service.dart` | Tokenization, Jaccard/Cosine metrics, perplexity scoring.

 |
| **Storage Layer** | SQLite (`sqflite`), SharedPreferences, IndexedDB | Native & Web offline persistence for metadata, profiles, and reports.

 |
| **Target Platforms** | Android, iOS, macOS, Windows, Linux, Web | Native platform runners (`MainActivity`, `AppDelegate`, `MainFlutterWindow`).

 |
| **Testing** | Flutter Test Framework, Dart Analyzer | Unit, widget, and isolate integration testing.

 |

---

##  System Architecture & Workflow

1. **Text Extraction:** Plain text is extracted from PDF uploads via vector reading or OCR image enhancement.


2. **String Normalization:** Text is lowercased, non-standard punctuation is stripped, and whitespace anomalies are removed.


3. **N-Gram Generation:** Text streams are broken down into token $N$-grams.


4. **Similarity Calculation:** Document overlap is computed using the Jaccard index:



$$\text{Similarity} = \frac{\vert{}A \cap B\vert{}}{\vert{}A \cup B\vert{}}$$


5. **Offset Mapping:** Overlapping token spans are saved into `MatchRange` objects for highlighting.


6. **Dual-Layer AI Analysis:** Perplexity heuristics and structural uniformity are measured to flag synthetic content.



---

##  Project Directory Structure

```text
lib/
├── main.dart                  # Application entry point, global theme, and root routes[cite: 1]
├── auth_service.dart          # User session management and credential persistence[cite: 1]
├── similarity_engine.dart     # String normalization, tokenization, and N-gram algorithms[cite: 1]
├── models/                    # Core data models
│   ├── app_user.dart          # User model and role definitions[cite: 1]
│   ├── assignment_document.dart# Document metadata model[cite: 1]
│   ├── comparison_result.dart # Pairwise match result model[cite: 1]
│   ├── match_range.dart       # Character offset span model[cite: 1]
│   └── batch_report_model.dart# Cohort matrix report model[cite: 1]
├── screens/                   # UI views and dashboards
│   ├── auth_screen.dart       # Login and Registration screen[cite: 1]
│   ├── upload_screen.dart     # Single/batch PDF upload view[cite: 1]
│   ├── batch_evaluation_screen.dart # Real-time batch processing view[cite: 1]
│   ├── results_screen.dart    # Comparison results and similarity matrix[cite: 1]
│   ├── document_viewer_screen.dart # Document viewer with highlighted matches[cite: 1]
│   └── profile_screen.dart    # User profile and threshold settings[cite: 1]
├── services/                  # Business logic and services
│   ├── pdf_service.dart       # Native PDF stream extraction[cite: 1]
│   ├── ocr_service.dart       # Tesseract and Vision OCR handling[cite: 1]
│   ├── similarity_service.dart# Pairwise similarity evaluation service[cite: 1]
│   ├── ai_detection_service.dart # Dual-layer AI authorship detection[cite: 1]
│   ├── batch_api_service.dart # REST API batch communication[cite: 1]
│   └── database_service.dart  # Adapter for SQLite / SharedPreferences persistence[cite: 1]
├── state/                     # State management layer
│   ├── app_state.dart         # Global app state definitions[cite: 1]
│   └── batch_cubit.dart       # Reactive batch execution Cubit[cite: 1]
└── widgets/                   # Reusable UI components
    ├── ui_kit.dart            # Custom buttons, cards, and input fields[cite: 1]
    ├── highlighted_text.dart  # Color-coded match span renderer[cite: 1]
    └── ai_authorship_dialog.dart # AI likelihood score modal[cite: 1]

```

---

##  Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.x or higher)


* [Dart SDK](https://dart.dev/get-started)

* Tesseract Language Data (`eng.traineddata`) placed in assets for offline OCR support



### Installation & Setup

1. **Clone the repository:**
```bash
git clone https://github.com/Mahikubagvat/FlutterProjects.git
cd FlutterProjects

```


2. **Install dependencies:**
```bash
flutter pub get

```


3. **Run the application:**
* **Desktop (macOS / Windows / Linux):**
```bash
flutter run -d macos
# or windows / linux

```


* **Web:**
```bash
flutter run -d chrome

```


* **Mobile (Android / iOS):**
```bash
flutter run

```





---

##  Testing & Quality Assurance

The application includes automated test suites covering similarity calculations, AI perplexity checks, isolate queues, and database operations.

```bash
# Run all unit, widget, and integration tests
flutter test

```

### Test Coverage Summary

* **Total Scenarios Executed:** 29


* **Pass Rate:** 100%


* **Tested Modules:** Authentication, PDF Parsing, OCR Processing, Similarity Engine, AI Authorship Detection, Batch Processing Queue, Persistence, Security Access, and Multi-Platform UI Responsiveness.



---

##  Limitations & Future Roadmap

### Limitations

* **OCR Overhead:** Scanned documents exceeding 100 pages require higher memory allocation and processing time.


* **Domain Sensitivity:** Heuristic perplexity scores may show variable sensitivity on highly technical or mathematical text.


* **Hardware Dependency:** Offline execution speed for large batch comparisons depends on host device CPU/memory capacity.



### Future Extensions

* **Cloud OCR Workers:** Offload heavy OCR processing to cloud GPU worker nodes.


* **LMS Integration:** Support LTI standards for integration with Canvas, Moodle, and Google Classroom.


* **Deep Learning Embeddings:** Integrate BERT/RoBERTa embeddings to detect paraphrased content and structural rewriting.



---
