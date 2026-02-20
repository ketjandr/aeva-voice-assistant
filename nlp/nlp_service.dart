/// AEVA NLP Service — Orchestrates the on-device ML inference pipeline.
///
/// This service manages the complete NLP pipeline lifecycle:
///   1. Initialization — loads TFLite model + vocabulary
///   2. Inference — preprocesses text → classifies intent → extracts entities
///   3. Dispatch — routes classified intents to action handlers
///
/// All inference runs on-device with sub-100ms latency, eliminating
/// API round-trips for real-time natural language interaction.

import 'package:flutter/material.dart';
import 'package:aevavoiceassistant/nlp/intent_classifier.dart';
import 'package:aevavoiceassistant/nlp/intent_config.dart';
import 'package:aevavoiceassistant/nlp/intent_dispatcher.dart';
import 'package:aevavoiceassistant/nlp/text_preprocessor.dart';

/// Singleton service for the AEVA NLP pipeline.
class NlpService {
  static final NlpService _instance = NlpService._internal();
  factory NlpService() => _instance;
  NlpService._internal();

  final IntentClassifier _classifier = IntentClassifier();
  IntentDispatcher? _dispatcher;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the NLP pipeline: load model, vocabulary, and preprocessor.
  ///
  /// Must be called once during app startup (e.g., in initState).
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _classifier.initialize();
    _isInitialized = true;

    debugPrint('[NlpService] Initialized — '
        '${IntentConfig.numIntents} intent categories, '
        'vocab loaded, model ready');
  }

  /// Configure the dispatcher with UI action callbacks.
  ///
  /// Called when the widget providing callbacks is available.
  void configureDispatcher({
    required DispatcherCallbacks callbacks,
    required BuildContext context,
  }) {
    _dispatcher = IntentDispatcher(
      callbacks: callbacks,
      context: context,
    );
  }

  /// Process a raw speech-to-text input through the full NLP pipeline.
  ///
  /// Pipeline stages:
  ///   1. Text preprocessing (normalization, tokenization, encoding)
  ///   2. TFLite intent classification (on-device inference)
  ///   3. Entity extraction (contact names, cities, durations, etc.)
  ///   4. Intent dispatch (action execution)
  ///
  /// Returns the [IntentResult] for debugging/logging purposes.
  Future<IntentResult> processInput(String rawText) async {
    assert(_isInitialized, 'NlpService not initialized. Call initialize() first.');
    assert(_dispatcher != null, 'Dispatcher not configured. Call configureDispatcher() first.');

    // Run intent classification (includes preprocessing)
    final result = _classifier.classify(rawText);

    debugPrint('[NlpService] $result');
    debugPrint('[NlpService] Entities: ${result.processedInput.entities}');

    // Dispatch to action handler
    await _dispatcher!.dispatch(result, rawText);

    return result;
  }

  /// Classify intent without dispatching (useful for testing/debugging).
  IntentResult classifyOnly(String rawText) {
    assert(_isInitialized, 'NlpService not initialized.');
    return _classifier.classify(rawText);
  }

  /// Get the text preprocessor for direct access.
  TextPreprocessor get preprocessor => _classifier.preprocessor;
}
