import 'dart:math' as math;

import 'trigger_word_service.dart';

enum SttBackend { iosSpeechToText, androidOfflineVosk }

class SttRefinementRequest {
  const SttRefinementRequest({
    required this.text,
    required this.isFinal,
    required this.backend,
    this.alternates = const [],
    this.recognizedPhrases = const [],
  });

  final String text;
  final bool isFinal;
  final SttBackend backend;
  final List<String> alternates;
  final List<String> recognizedPhrases;
}

class SttTranscriptRefinementService {
  SttTranscriptRefinementService({TriggerWordService? triggerWordService})
      : _triggerWordService = triggerWordService ?? TriggerWordService();

  static const String _brandName = 'SenScribe';
  static const Set<String> _strongContextTokens = {
    'open',
    'launch',
    'start',
    'use',
    'using',
    'app',
    'application',
    'called',
    'named',
    'settings',
    'setting',
    'screen',
    'page',
    'feature',
    'features',
    'tool',
    'mode',
    'home',
    'voice',
    'speech',
    'text',
  };
  static const Set<String> _identityContextTokens = {
    'is',
    'are',
    'was',
    'were',
    'called',
    'named',
  };
  static const Set<String> _weakContextTokens = {'with', 'in', 'on'};
  static const Set<String> _subscribeBlockerFollowers = {'to', 'for'};
  static const Set<String> _brandLeadTokens = {
    'sen',
    'sens',
    'sense',
    'send',
    'sends',
    'since',
    'cents',
    'descends',
  };
  static const Set<String> _brandTailTokens = {
    'scribe',
    'describe',
    'gripe',
    'grape',
    'great',
    'grade',
    'script',
    'scrape',
  };
  static const List<_PhraseAlias> _aliases = [
    _PhraseAlias(['sense', 'gripe']),
    _PhraseAlias(['sense', 'great']),
    _PhraseAlias(['sen', 'describe']),
    _PhraseAlias(['send', 'a', 'scribe']),
    _PhraseAlias(['send', 'scribe']),
    _PhraseAlias(['sens', 'great']),
    _PhraseAlias(['sense', 'scribe']),
    _PhraseAlias(['sub', 'scribe'], highRisk: true),
    _PhraseAlias(['sen', 'scribe']),
    _PhraseAlias(['senscribe']),
    _PhraseAlias(['subscribe'], highRisk: true),
  ];
  static const List<List<String>> _supportAliases = [
    ['senscribe'],
    ['sen', 'scribe'],
    ['sen', 'describe'],
    ['sens', 'great'],
    ['sense', 'gripe'],
    ['sense', 'great'],
    ['sense', 'scribe'],
  ];

  final TriggerWordService _triggerWordService;

  String refine(SttRefinementRequest request) {
    final trimmed = request.text.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final brandCorrected = _refineBrandName(request);
    final triggerCorrected =
        _triggerWordService.refineRecognizedText(brandCorrected);
    return _normalizeCanonicalBrandForms(triggerCorrected);
  }

  String _normalizeCanonicalBrandForms(String text) {
    final source = text.trim();
    if (source.isEmpty) {
      return source;
    }

    final tokens = _tokenize(source);
    if (tokens.isEmpty) {
      return source;
    }

    final replacements = <_TextReplacement>[];
    final reserved = List<bool>.filled(tokens.length, false);

    for (final alias in _supportAliases) {
      final aliasLength = alias.length;
      if (aliasLength > tokens.length) {
        continue;
      }

      for (var start = 0; start <= tokens.length - aliasLength; start++) {
        if (_windowContainsReserved(reserved, start, aliasLength)) {
          continue;
        }
        if (!_matchesAlias(tokens, start, alias)) {
          continue;
        }

        final end = start + aliasLength - 1;
        replacements.add(
          _TextReplacement(
            start: tokens[start].start,
            end: tokens[end].end,
            replacement: _brandName,
          ),
        );
        for (var index = start; index <= end; index++) {
          reserved[index] = true;
        }
      }
    }

    if (replacements.isEmpty) {
      return source;
    }

    final buffer = StringBuffer();
    var cursor = 0;
    for (final replacement in replacements
      ..sort((a, b) => a.start.compareTo(b.start))) {
      buffer.write(source.substring(cursor, replacement.start));
      buffer.write(replacement.replacement);
      cursor = replacement.end;
    }
    buffer.write(source.substring(cursor));
    return buffer.toString().trim();
  }

  String _refineBrandName(SttRefinementRequest request) {
    final source = request.text.trim();
    final tokens = _tokenize(source);
    if (tokens.isEmpty) {
      return source;
    }

    final hasIosSupport = _hasIosSupportingEvidence(request);
    final replacements = <_TextReplacement>[];
    final reserved = List<bool>.filled(tokens.length, false);

    for (final alias in _aliases) {
      final aliasLength = alias.tokens.length;
      if (aliasLength > tokens.length) {
        continue;
      }

      for (var start = 0; start <= tokens.length - aliasLength; start++) {
        if (_windowContainsReserved(reserved, start, aliasLength)) {
          continue;
        }
        if (!_matchesAlias(tokens, start, alias.tokens)) {
          continue;
        }
        if (!_shouldReplaceAlias(
          alias,
          tokens,
          start,
          request: request,
          hasIosSupport: hasIosSupport,
        )) {
          continue;
        }

        final end = start + aliasLength - 1;
        replacements.add(
          _TextReplacement(
            start: tokens[start].start,
            end: tokens[end].end,
            replacement: _brandName,
          ),
        );
        for (var index = start; index <= end; index++) {
          reserved[index] = true;
        }
      }
    }

    for (var start = 0; start < tokens.length; start++) {
      final dynamicMatch = _matchDynamicBrandPhrase(tokens, start);
      if (dynamicMatch == null) {
        continue;
      }
      if (_windowContainsReserved(reserved, start, dynamicMatch.length)) {
        continue;
      }
      if (!_shouldReplaceAlias(
        dynamicMatch.alias,
        tokens,
        start,
        request: request,
        hasIosSupport: hasIosSupport,
      )) {
        continue;
      }

      final end = start + dynamicMatch.length - 1;
      replacements.add(
        _TextReplacement(
          start: tokens[start].start,
          end: tokens[end].end,
          replacement: _brandName,
        ),
      );
      for (var index = start; index <= end; index++) {
        reserved[index] = true;
      }
    }

    if (replacements.isEmpty) {
      return source;
    }

    final buffer = StringBuffer();
    var cursor = 0;
    for (final replacement in replacements
      ..sort((a, b) => a.start.compareTo(b.start))) {
      buffer.write(source.substring(cursor, replacement.start));
      buffer.write(replacement.replacement);
      cursor = replacement.end;
    }
    buffer.write(source.substring(cursor));
    return buffer.toString().trim();
  }

  bool _shouldReplaceAlias(
    _PhraseAlias alias,
    List<_TokenSpan> tokens,
    int start, {
    required SttRefinementRequest request,
    required bool hasIosSupport,
  }) {
    if (!alias.highRisk) {
      return true;
    }

    final end = start + alias.tokens.length;
    if (_isBlockedHighRiskUse(alias, tokens, start, end)) {
      return false;
    }

    if (_hasStrongContext(tokens, start, end) ||
        _hasWelcomeContext(tokens, start, end) ||
        _hasIdentityContext(tokens, start, end)) {
      return true;
    }

    if (_hasWeakContext(tokens, start, end) && hasIosSupport) {
      return true;
    }

    if (hasIosSupport) {
      return true;
    }

    if (_shouldReplaceStandalonePartial(alias, tokens, request)) {
      return true;
    }

    return request.isFinal && tokens.length == alias.tokens.length;
  }

  bool _shouldReplaceStandalonePartial(
    _PhraseAlias alias,
    List<_TokenSpan> tokens,
    SttRefinementRequest request,
  ) {
    if (request.isFinal || tokens.length != alias.tokens.length) {
      return false;
    }

    if (_tokensEqual(alias.tokens, const ['subscribe']) ||
        _tokensEqual(alias.tokens, const ['sub', 'scribe'])) {
      return request.backend == SttBackend.iosSpeechToText &&
          tokens.length <= 2;
    }

    if (_tokensEqual(alias.tokens, const ['send', 'scribe']) ||
        _tokensEqual(alias.tokens, const ['send', 'a', 'scribe'])) {
      return tokens.length <= 3;
    }

    return false;
  }

  bool _isBlockedHighRiskUse(
    _PhraseAlias alias,
    List<_TokenSpan> tokens,
    int start,
    int end,
  ) {
    final isSubscribeAlias = _tokensEqual(alias.tokens, const ['subscribe']) ||
        _tokensEqual(alias.tokens, const ['sub', 'scribe']);
    if (!isSubscribeAlias) {
      return false;
    }

    if (end < tokens.length &&
        _subscribeBlockerFollowers.contains(tokens[end].value)) {
      return true;
    }

    if (start > 0 && tokens[start - 1].value == 'and') {
      return true;
    }

    if (start > 1 &&
        tokens[start - 2].value == 'like' &&
        tokens[start - 1].value == 'and') {
      return true;
    }

    if (start > 0 &&
        tokens[start - 1].value == 'please' &&
        end == tokens.length) {
      return true;
    }

    return false;
  }

  bool _hasStrongContext(List<_TokenSpan> tokens, int start, int end) {
    final nearby = _nearbyTokens(tokens, start, end);
    return nearby.any((token) => _strongContextTokens.contains(token));
  }

  bool _hasWeakContext(List<_TokenSpan> tokens, int start, int end) {
    final nearby = _nearbyTokens(tokens, start, end);
    return nearby.any((token) => _weakContextTokens.contains(token));
  }

  bool _hasWelcomeContext(List<_TokenSpan> tokens, int start, int end) {
    if (start >= 2 &&
        tokens[start - 2].value == 'welcome' &&
        tokens[start - 1].value == 'to') {
      return true;
    }
    if (start >= 1 && tokens[start - 1].value == 'welcome') {
      return true;
    }
    if (end < tokens.length &&
        tokens[end - 1].value == 'to' &&
        end >= 2 &&
        tokens[end - 2].value == 'welcome') {
      return true;
    }
    return false;
  }

  bool _hasIdentityContext(List<_TokenSpan> tokens, int start, int end) {
    if (start > 0 && _identityContextTokens.contains(tokens[start - 1].value)) {
      return true;
    }
    if (end < tokens.length &&
        _identityContextTokens.contains(tokens[end].value)) {
      return true;
    }
    return false;
  }

  Iterable<String> _nearbyTokens(
      List<_TokenSpan> tokens, int start, int end) sync* {
    final windowStart = math.max(0, start - 2);
    final windowEnd = math.min(tokens.length, end + 2);
    for (var index = windowStart; index < windowEnd; index++) {
      if (index >= start && index < end) {
        continue;
      }
      yield tokens[index].value;
    }
  }

  bool _hasIosSupportingEvidence(SttRefinementRequest request) {
    if (request.backend != SttBackend.iosSpeechToText) {
      return false;
    }

    final evidence = <String>[
      ...request.alternates,
      ...request.recognizedPhrases,
    ];
    for (final phrase in evidence) {
      final tokens = _tokenize(phrase.trim());
      if (tokens.isEmpty) {
        continue;
      }
      for (final alias in _supportAliases) {
        if (_containsPhrase(tokens, alias)) {
          return true;
        }
      }
    }
    return false;
  }

  _DynamicBrandMatch? _matchDynamicBrandPhrase(
    List<_TokenSpan> tokens,
    int start,
  ) {
    final remaining = tokens.length - start;
    if (remaining >= 3 &&
        _looksLikeBrandLead(tokens[start].value) &&
        _isBridgeToken(tokens[start + 1].value) &&
        _looksLikeBrandTail(tokens[start + 2].value)) {
      return const _DynamicBrandMatch(
        alias: _PhraseAlias(['dynamic', 'a', 'dynamic']),
        length: 3,
      );
    }

    if (remaining >= 2 &&
        _looksLikeBrandLead(tokens[start].value) &&
        _looksLikeBrandTail(tokens[start + 1].value)) {
      return const _DynamicBrandMatch(
        alias: _PhraseAlias(['dynamic', 'dynamic']),
        length: 2,
      );
    }

    return null;
  }

  bool _looksLikeBrandLead(String token) {
    if (_brandLeadTokens.contains(token)) {
      return true;
    }
    return token.startsWith('sen') ||
        token.startsWith('sens') ||
        token.startsWith('send') ||
        token == 'descends';
  }

  bool _looksLikeBrandTail(String token) {
    if (_brandTailTokens.contains(token)) {
      return true;
    }
    return token.endsWith('scribe') ||
        token.startsWith('scrib') ||
        token.startsWith('grip') ||
        token.startsWith('grap') ||
        token.startsWith('grea') ||
        token.startsWith('grad') ||
        token.startsWith('scr');
  }

  bool _isBridgeToken(String token) => token == 'a' || token == 'the';

  bool _containsPhrase(List<_TokenSpan> tokens, List<String> phrase) {
    if (phrase.length > tokens.length) {
      return false;
    }
    for (var start = 0; start <= tokens.length - phrase.length; start++) {
      if (_matchesAlias(tokens, start, phrase)) {
        return true;
      }
    }
    return false;
  }

  bool _windowContainsReserved(List<bool> reserved, int start, int length) {
    for (var index = start; index < start + length; index++) {
      if (reserved[index]) {
        return true;
      }
    }
    return false;
  }

  bool _matchesAlias(
    List<_TokenSpan> observed,
    int start,
    List<String> target,
  ) {
    for (var index = 0; index < target.length; index++) {
      if (observed[start + index].value != target[index]) {
        return false;
      }
    }
    return true;
  }

  bool _tokensEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  List<_TokenSpan> _tokenize(String text) {
    final expression = RegExp(r"[a-z0-9']+");
    return expression
        .allMatches(text.toLowerCase())
        .map(
          (match) => _TokenSpan(
            value: match.group(0) ?? '',
            start: match.start,
            end: match.end,
          ),
        )
        .where((token) => token.value.isNotEmpty)
        .toList();
  }
}

class _PhraseAlias {
  const _PhraseAlias(this.tokens, {this.highRisk = false});

  final List<String> tokens;
  final bool highRisk;
}

class _TokenSpan {
  const _TokenSpan({
    required this.value,
    required this.start,
    required this.end,
  });

  final String value;
  final int start;
  final int end;
}

class _TextReplacement {
  const _TextReplacement({
    required this.start,
    required this.end,
    required this.replacement,
  });

  final int start;
  final int end;
  final String replacement;
}

class _DynamicBrandMatch {
  const _DynamicBrandMatch({
    required this.alias,
    required this.length,
  });

  final _PhraseAlias alias;
  final int length;
}
