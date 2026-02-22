# AEVA Voice Assistant

A Flutter-based voice assistant powered by on-device NLP. AEVA uses a quantized TensorFlow Lite model for real-time intent classification, achieving ~93% accuracy across 15 intent categories with sub-100ms inference — no cloud API round-trips required.

## Features

- **Voice interaction** — Speech-to-text input with text-to-speech responses
- **On-device ML** — TFLite intent classification runs entirely on the device
- **15 intent categories** — Email, contacts, weather, timer, music, navigation, calculator, spelling, app control, search, date/time, conversation, identity, device settings, and fallback
- **Entity extraction** — Automatically extracts contact names, cities, durations, and more from natural language
- **Dark / light mode** — Toggleable theme with persistent preferences
- **Onboarding flow** — First-launch walkthrough for new users
- **Cross-platform** — Runs on both Android and iOS

## Project Structure

```
├── main.dart                  # App entry point and main UI
├── assets/                    # Icons and static assets
├── data/
│   ├── command_data.dart      # Command library definitions
│   ├── music_data.dart        # Music genre data
│   └── weather_locations.dart # Weather location presets
├── ml/
│   ├── train_intent_model.py  # Python training pipeline
│   ├── training_data.json     # Intent training samples
│   └── vocab.json             # Token-to-index vocabulary
├── nlp/
│   ├── intent_classifier.dart # TFLite model wrapper
│   ├── intent_config.dart     # Intent labels and thresholds
│   ├── intent_dispatcher.dart # Intent-to-action routing
│   ├── nlp_service.dart       # NLP pipeline orchestrator
│   └── text_preprocessor.dart # Tokenization and encoding
├── page/                      # UI pages (about, onboarding, command library)
├── utils/                     # Helpers, preferences, directions
└── widget/                    # Reusable UI components
```

## NLP Pipeline

```
Raw speech text
  → Text preprocessing (normalize, tokenize, encode)
  → TFLite intent classification (Embedding → Conv1D → GlobalMaxPool → Dense → Softmax)
  → Entity extraction (names, locations, numbers)
  → Intent dispatch (execute action)
```

The model is trained with data augmentation (random word dropout, synonym insertion, word reordering, prefix/suffix addition) to improve robustness against speech-to-text variations.

## Training the Model

The training pipeline lives in `ml/` and uses TensorFlow/Keras:

```bash
cd ml
python train_intent_model.py
```

**Outputs:**
| File | Description |
|------|-------------|
| `intent_model.tflite` | Quantized int8 TFLite model |
| `vocab.json` | Token-to-index vocabulary |
| `label_map.json` | Index-to-intent-label mapping |
| `training_report.json` | Training metrics and evaluation |

**Hyperparameters:**
| Parameter | Value |
|-----------|-------|
| Sequence length | 32 |
| Vocab size | 5,000 |
| Embedding dim | 64 |
| Conv1D filters | 128 |
| Epochs | 80 |
| Batch size | 16 |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Python 3.10+ (for model training)
- Xcode (iOS) / Android Studio (Android)

### Run the app

```bash
flutter pub get
flutter run
```

### Train a new model (optional)

```bash
pip install tensorflow numpy
python ml/train_intent_model.py
```

Then copy `ml/intent_model.tflite` and `ml/vocab.json` into `assets/ml/`.

## Supported Commands

| Category | Examples |
|----------|---------|
| Email | "Send an email to Sarah" |
| Contacts | "Call mom", "Text David" |
| Weather | "Weather in London", "Is it raining?" |
| Timer | "Set a timer for 5 minutes" |
| Music | "Play jazz music" |
| Navigation | "Open Google Maps" |
| Calculate | "What is 2 + 2?" |
| Spelling | "Spell onomatopoeia" |
| Search | "Search for black holes" |
| Date/Time | "What time is it?" |
| Settings | "Turn on dark mode" |

## License

This project is for personal/educational use.
