/// Intent categories for the TFLite intent-classification model.
///
/// The model is trained on 15 intent categories covering app control,
/// navigation, information retrieval, and conversational interactions.
/// Each intent maps to a label index used by the quantized TFLite model.

class IntentLabel {
  final int index;
  final String name;
  final String description;

  const IntentLabel({
    required this.index,
    required this.name,
    required this.description,
  });
}

class IntentConfig {
  /// Maximum sequence length for the TFLite model input tensor.
  static const int maxSequenceLength = 32;

  /// Vocabulary size used during tokenization.
  static const int vocabSize = 5000;

  /// Embedding dimension for the model.
  static const int embeddingDim = 64;

  /// Confidence threshold for intent classification.
  /// Below this threshold, the fallback intent is triggered.
  static const double confidenceThreshold = 0.45;

  /// All 15 intent categories supported by the model.
  static const List<IntentLabel> intentLabels = [
    IntentLabel(index: 0, name: 'email', description: 'Send an email'),
    IntentLabel(index: 1, name: 'contacts', description: 'Call, message, or FaceTime a contact'),
    IntentLabel(index: 2, name: 'weather', description: 'Get current weather information'),
    IntentLabel(index: 3, name: 'timer', description: 'Set a countdown timer'),
    IntentLabel(index: 4, name: 'music', description: 'Play music or songs'),
    IntentLabel(index: 5, name: 'navigation', description: 'Open maps or navigation'),
    IntentLabel(index: 6, name: 'calculate', description: 'Perform arithmetic calculations'),
    IntentLabel(index: 7, name: 'spelling', description: 'Spell a word'),
    IntentLabel(index: 8, name: 'app_control', description: 'Open settings, library, apps, or control UI'),
    IntentLabel(index: 9, name: 'search', description: 'Search Google or define something'),
    IntentLabel(index: 10, name: 'datetime', description: 'Get current date and time'),
    IntentLabel(index: 11, name: 'conversation', description: 'Greetings, jokes, stories, and chitchat'),
    IntentLabel(index: 12, name: 'identity', description: 'Questions about AEVA identity or developer'),
    IntentLabel(index: 13, name: 'device_settings', description: 'Toggle dark/light mode, voice, auto-activation'),
    IntentLabel(index: 14, name: 'fallback', description: 'Unrecognized or ambiguous input'),
  ];

  /// Retrieve an intent label by its index.
  static IntentLabel getLabelByIndex(int index) {
    if (index < 0 || index >= intentLabels.length) {
      return intentLabels.last; // fallback
    }
    return intentLabels[index];
  }

  /// Retrieve an intent label by its name.
  static IntentLabel getLabelByName(String name) {
    return intentLabels.firstWhere(
      (label) => label.name == name,
      orElse: () => intentLabels.last,
    );
  }

  /// Number of intent categories.
  static int get numIntents => intentLabels.length;
}
