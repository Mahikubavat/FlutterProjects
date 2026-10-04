# Plagiarism Checker for PDF Lab Assignments (Flutter prototype)

A runnable prototype: upload PDF lab reports or images, extract their text,
compare every pair for similarity, highlight copied passages, and export a PDF
summary report. Local analysis works offline; optional semantic analysis uses
an LLM API.

## Workflow implemented

1. **Extract text from PDF or image** — embedded PDF text is accepted only when
   it passes a low-confidence heuristic. Otherwise, `pdfx` renders every PDF
   page and Tesseract OCR processes the images. JPG, PNG, WEBP, and BMP uploads
   go directly through the same OCR handler.
   Low-confidence OCR can optionally be sent to a vision model for handwriting.
2. **Compare content** — `lib/services/similarity_service.dart` runs a local
   shingling + cosine-similarity algorithm. If `LLM_API_KEY` is supplied, the
   app also calls an OpenAI-compatible endpoint for deep paraphrase detection
   and blends that semantic score into the ranking.
3. **Generate report** — `lib/screens/results_screen.dart` shows a ranked,
   color-coded similarity table; `lib/screens/detail_screen.dart` shows the
   two texts side by side with matching passages highlighted in yellow;
   `lib/services/report_service.dart` exports it all as a downloadable PDF.

## Project layout

```
lib/
  main.dart                     entry point
  models/                       AssignmentDocument, ComparisonResult, MatchRange, TokenSpan
  services/
   pdf_service.dart            PDF -> text, with rendered-page OCR fallback
   ocr_service.dart            page image -> Tesseract text
   document_text_service.dart  shared PDF/image extraction pipeline
   vision_ocr_service.dart     optional handwriting transcription API client
    similarity_service.dart     text -> similarity scores + matched ranges
   llm_similarity_service.dart optional semantic comparison API client
    report_service.dart         results -> downloadable PDF report
  state/app_state.dart          app-wide state (Provider/ChangeNotifier)
  screens/
    upload_screen.dart          upload PDFs / load sample set
    results_screen.dart         ranked similarity table + export button
    detail_screen.dart          side-by-side highlighted comparison
  widgets/highlighted_text.dart renders text with highlighted match ranges
  sample_data/sample_documents.dart  3 built-in sample "lab reports" for demoing
```

## How to run it

1. Install the Flutter SDK (3.19+) if you don't have it:
   https://docs.flutter.dev/get-started/install
2. From this folder:
   ```bash
   flutter pub get
   flutter run -d chrome        # easiest: runs in a browser tab
   # or: flutter run -d macos / -d windows / -d linux / a connected device
   ```
3. In the app, click **"Load sample set"** to instantly see a flagged
   high-similarity pair (two reports with a copy-pasted results section)
   and a low-similarity original report — no PDFs needed to try it.
4. Or click **"Upload PDFs or images"**, pick 2+ real documents, then
   **"Analyze"**. Tap any row in the results to see the highlighted
   side-by-side comparison. Use the PDF icon in the app bar to export
   the report.

**Note on package versions:** `pubspec.yaml` pins reasonable recent
versions, but I couldn't check pub.dev live while building this. If
`flutter pub get` complains about a version, run
`flutter pub upgrade --major-versions` or loosen the version constraint.

**Note on Syncfusion:** `syncfusion_flutter_pdf`'s text extraction works
out of the box for development/evaluation. If you deploy this
commercially, register for their free Community License (or a paid one)
per their licensing terms and call `SyncfusionLicense.registerLicense(...)`
before `runApp()`.

## OCR and LLM configuration

Tesseract OCR uses bundled English language data. Native OCR is intended for
Android and iOS; the package also provides a web implementation through
Tesseract.js. Test desktop targets separately before deployment.

To enable semantic comparison for a local prototype:

```bash
flutter run -d chrome --dart-define=LLM_API_KEY=your-key
```

The default endpoint is OpenAI's chat completions API. Set `LLM_ENDPOINT` and
`LLM_MODEL` for an OpenAI-compatible gateway or model. For handwriting
transcription, also provide `VISION_OCR_API_KEY`; override its endpoint/model
with `VISION_OCR_ENDPOINT` and `VISION_OCR_MODEL`.

Do not ship provider keys in a public client application; production
deployments should proxy both services through an authenticated backend.

## What I'd extend first

1. **A persistence/backend layer.** Everything currently lives in memory
   and resets on app restart. For a real class, you'd want a backend
   (e.g. a small Node/FastAPI service + Postgres, or Firebase) to store
   submissions, run comparisons server-side (so students can't just
   inspect the client), and support instructor accounts/permissions.
2. **A corpus check, not just pairwise-in-batch.** Real plagiarism
   checkers also compare against past semesters' submissions and public
   web sources, not only the current upload batch. That means storing a
   growing document index and possibly adding a web-search step.
3. **Performance for large classes.** `compareAll` is O(n²) comparisons
   run synchronously; fine for a section of ~30, but move it to
   `compute()`/an isolate (or the backend) once class sizes or document
   lengths grow, and consider MinHash/LSH to avoid full pairwise
   comparison at scale.
4. **Tune/expose the thresholds.** The 40%/60% flag thresholds and the
   70/30 shingle/cosine weighting are constants right now
   (`similarity_service.dart`) — surfacing them as instructor-adjustable
   settings would make this much more usable in practice.
