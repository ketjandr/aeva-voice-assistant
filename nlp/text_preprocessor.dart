/// Natural language preprocessing pipeline for on-device NLP inference.
///
/// Implements tokenization, sequence padding/truncation, and vocabulary
/// encoding to transform raw speech-to-text output into integer sequences
/// compatible with the quantized TFLite intent-classification model.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:aevavoiceassistant/nlp/intent_config.dart';

/// Represents a preprocessed input ready for model inference.
class ProcessedInput {
  /// Tokenized and padded integer sequence.
  final List<int> tokenIds;

  /// Original cleaned text.
  final String cleanedText;

  /// Extracted entity tokens (e.g., names, places, numbers).
  final Map<String, String> entities;

  const ProcessedInput({
    required this.tokenIds,
    required this.cleanedText,
    required this.entities,
  });
}

/// Text preprocessing pipeline that mirrors the Python training pipeline.
///
/// Steps:
/// 1. Normalization — lowercase, strip punctuation, correct common STT errors
/// 2. Tokenization — split into word tokens
/// 3. Vocabulary encoding — map tokens to integer IDs via the exported vocab
/// 4. Sequence padding/truncation — fix to [IntentConfig.maxSequenceLength]
/// 5. Entity extraction — pull out slots like contact names, city names, durations
class TextPreprocessor {
  /// Word-to-index vocabulary loaded from the exported vocab JSON.
  Map<String, int> _vocab = {};

  /// Out-of-vocabulary token index.
  static const int _oovIndex = 1;

  /// Padding token index.
  static const int _padIndex = 0;

  /// Whether the vocabulary has been loaded.
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Common STT misrecognitions for "AEVA".
  static const List<String> _aevaAliases = ['ava', 'eva', 'aeva', 'ava\'s', 'eva\'s'];

  /// Stop words to remove during preprocessing for intent classification.
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been',
    'do', 'does', 'did', 'has', 'have', 'had', 'it', 'its',
    'of', 'at', 'by', 'up', 'in', 'on', 'to', 'for', 'with',
    'this', 'that', 'there', 'here',
  };

  /// Initialize the preprocessor by loading the vocabulary file.
  ///
  /// The vocab JSON is exported from the Python training pipeline
  /// and bundled as a Flutter asset.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final jsonString = await rootBundle.loadString('assets/ml/vocab.json');
      final Map<String, dynamic> rawVocab = json.decode(jsonString);
      _vocab = rawVocab.map((key, value) => MapEntry(key, value as int));
      _isInitialized = true;
    } catch (e) {
      // If vocab file not found, build a default vocabulary from training data.
      _buildDefaultVocab();
      _isInitialized = true;
    }
  }

  /// Build a fallback vocabulary from common intent keywords.
  void _buildDefaultVocab() {
    final keywords = <String>[
      '<PAD>', '<OOV>',
      // High-frequency intent words
      'email', 'send', 'call', 'message', 'text', 'facetime', 'contact',
      'weather', 'temperature', 'forecast', 'rain', 'sunny', 'cloudy',
      'timer', 'set', 'seconds', 'minutes', 'hours', 'hour', 'minute', 'second',
      'play', 'music', 'song', 'stop', 'pause',
      'open', 'maps', 'map', 'navigate', 'directions', 'location', 'where',
      'calculate', 'what', 'plus', 'minus', 'times', 'divided',
      'spell', 'word', 'spelling',
      'settings', 'library', 'help', 'about', 'feedback', 'panel',
      'search', 'google', 'define', 'translate',
      'time', 'date', 'day', 'today', 'now', 'current',
      'hello', 'hi', 'hey', 'joke', 'story', 'how', 'are', 'you',
      'name', 'who', 'made', 'created', 'developer',
      'dark', 'light', 'mode', 'theme', 'voice', 'male', 'female',
      'auto', 'activation', 'enable', 'disable',
      'instagram', 'facebook', 'whatsapp', 'youtube', 'spotify',
      'twitter', 'snapchat', 'telegram', 'netflix', 'discord',
      'zoom', 'uber', 'tiktok', 'twitch',
      'please', 'can', 'could', 'would', 'tell', 'me', 'my',
      'turn', 'on', 'off', 'switch', 'change', 'get', 'find',
      'good', 'morning', 'afternoon', 'evening', 'night',
      'thank', 'thanks', 'love', 'like', 'friend', 'family',
      'smart', 'stupid', 'robot', 'human', 'test', 'testing',
      'knock', 'sing', 'hobby', 'school', 'exercise',
      'am', 'i', 'right', 'currently', 'place',
      'microphone', 'contacts', 'permission',
    ];

    for (int i = 0; i < keywords.length; i++) {
      _vocab[keywords[i]] = i;
    }
  }

  /// Full preprocessing pipeline: normalize → tokenize → encode → pad.
  ProcessedInput process(String rawText) {
    final cleaned = _normalize(rawText);
    final tokens = _tokenize(cleaned);
    final entities = _extractEntities(rawText, tokens);
    final encoded = _encode(tokens);
    final padded = _padOrTruncate(encoded);

    return ProcessedInput(
      tokenIds: padded,
      cleanedText: cleaned,
      entities: entities,
    );
  }

  /// Step 1: Normalize the raw STT text.
  String _normalize(String text) {
    var normalized = text.toLowerCase().trim();

    // Correct common STT misrecognitions
    for (final alias in _aevaAliases) {
      normalized = normalized.replaceAll(alias, 'aeva');
    }

    // Remove punctuation except mathematical operators
    normalized = normalized.replaceAll(RegExp(r"[^\w\s+\-*/^.]"), '');

    // Collapse multiple spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  /// Step 2: Tokenize into word tokens.
  List<String> _tokenize(String text) {
    return text.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Step 3: Encode tokens to integer IDs via vocabulary lookup.
  List<int> _encode(List<String> tokens) {
    return tokens.map((token) {
      return _vocab[token] ?? _oovIndex;
    }).toList();
  }

  /// Step 4: Pad or truncate to fixed sequence length.
  List<int> _padOrTruncate(List<int> sequence) {
    if (sequence.length > IntentConfig.maxSequenceLength) {
      return sequence.sublist(0, IntentConfig.maxSequenceLength);
    }
    while (sequence.length < IntentConfig.maxSequenceLength) {
      sequence.add(_padIndex);
    }
    return sequence;
  }

  /// Step 5: Extract named entities / slots from the input.
  Map<String, String> _extractEntities(String rawText, List<String> tokens) {
    final entities = <String, String>{};
    final lower = rawText.toLowerCase();

    // Extract contact name after call/message/text/facetime
    _extractAfterKeyword(lower, ['call', 'facetime', 'message', 'text'], 'contact_name', entities);

    // Extract city after weather keywords
    _extractAfterKeyword(lower, ['weather in', 'weather at', 'weather for'], 'city', entities);

    // Extract duration components for timer
    _extractTimerEntities(lower, entities);

    // Extract music genre/keyword
    _extractBeforeKeyword(lower, ['music', 'song'], 'music_keyword', entities);

    // Extract app name after "open"
    _extractAfterKeyword(lower, ['open'], 'app_name', entities);

    // Extract search query
    _extractSearchQuery(lower, entities);

    // Extract spell word
    _extractAfterKeyword(lower, ['spell'], 'spell_word', entities);

    // Extract math expression
    _extractMathExpression(rawText, entities);

    return entities;
  }

  void _extractAfterKeyword(String text, List<String> keywords, String entityKey, Map<String, String> entities) {
    for (final keyword in keywords) {
      final idx = text.indexOf(keyword);
      if (idx != -1) {
        final afterKeyword = text.substring(idx + keyword.length).trim();
        // Clean common filler words
        var cleaned = afterKeyword
            .replaceAll(RegExp(r'^(please|to|for|me|the|a|an)\s+'), '')
            .trim();
        if (cleaned.isNotEmpty) {
          entities[entityKey] = cleaned;
          return;
        }
      }
    }
  }

  void _extractBeforeKeyword(String text, List<String> keywords, String entityKey, Map<String, String> entities) {
    for (final keyword in keywords) {
      final idx = text.indexOf(keyword);
      if (idx > 0) {
        final beforeKeyword = text.substring(0, idx).trim();
        final words = beforeKeyword.split(' ');
        if (words.isNotEmpty) {
          // Take the last meaningful word before the keyword
          final lastWord = words.last.replaceAll(RegExp(r'^(play|turn|on|a|an|some)\s*'), '').trim();
          if (lastWord.isNotEmpty && !_stopWords.contains(lastWord)) {
            entities[entityKey] = lastWord;
            return;
          }
        }
      }
    }
  }

  void _extractTimerEntities(String text, Map<String, String> entities) {
    final hourMatch = RegExp(r'(\d+)\s*hours?').firstMatch(text);
    final minuteMatch = RegExp(r'(\d+)\s*minutes?').firstMatch(text);
    final secondMatch = RegExp(r'(\d+)\s*seconds?').firstMatch(text);

    if (hourMatch != null) entities['timer_hours'] = hourMatch.group(1)!;
    if (minuteMatch != null) entities['timer_minutes'] = minuteMatch.group(1)!;
    if (secondMatch != null) entities['timer_seconds'] = secondMatch.group(1)!;

    // Handle "one second" edge case
    if (text.contains('one second')) entities['timer_seconds'] = '1';
  }

  void _extractSearchQuery(String text, Map<String, String> entities) {
    final patterns = ['search for', 'search', 'what is', 'define', 'google', 'translate'];
    for (final pattern in patterns) {
      final idx = text.indexOf(pattern);
      if (idx != -1) {
        var query = text.substring(idx + pattern.length).trim();
        query = query.replaceAll(RegExp(r'^(for|about|the|a|an)\s+'), '').trim();
        if (query.isNotEmpty) {
          entities['search_query'] = query;
          return;
        }
      }
    }
  }

  void _extractMathExpression(String rawText, Map<String, String> entities) {
    // Check if the text contains mathematical operators
    if (RegExp(r'[+\-*/^]').hasMatch(rawText)) {
      var expression = rawText.toLowerCase()
          .replaceAll(RegExp(r'(what is|calculate|count|the)\s*'), '')
          .replaceAll('square root of', 'sqrt')
          .replaceAll('squared', '^2')
          .replaceAll('cubed', '^3')
          .trim();
      if (expression.isNotEmpty) {
        entities['math_expression'] = expression;
      }
    }
  }
}
