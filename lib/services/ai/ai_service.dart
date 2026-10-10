import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../data/mock_data.dart' show raniProfile;
import '../../data/models.dart';
import '../../logic/cover_letter.dart';
import '../../logic/interview.dart';
import '../../logic/interview.dart' as heuristic show gradeAnswer;
import 'ai_parsing.dart';
import 'prompts.dart';

/// A CV picked by the user, kept in memory only until it is read.
class CvFile {
  const CvFile({required this.bytes, required this.mimeType, required this.source});
  final Uint8List bytes;

  /// `application/pdf` or `image/jpeg`.
  final String mimeType;
  final ProfileSource source;

  String get extension => mimeType == 'application/pdf' ? 'pdf' : 'jpg';
}

/// A generated cover letter; [offline] when it came from the template because the AI was unavailable.
typedef GeneratedLetter = ({String text, bool offline});

abstract interface class AiService {
  /// Reads a CV into a profile the user then reviews. Throws [AiFailure].
  Future<Profile> extractProfile(CvFile cv, {required List<Skill> catalog});

  Future<AnswerScore> gradeAnswer({required Job job, required InterviewQuestion question, required String answer});

  Future<GeneratedLetter> generateLetter({required Job job, required Profile profile, required LetterTone tone, required int variant});
}

/// The prototype's local logic: heuristic grading, template letters and Rani's CV as the "extracted" profile.
/// Used by mock builds and as the fallback when Gemini is unavailable.
class OfflineAiService implements AiService {
  const OfflineAiService();

  @override
  Future<Profile> extractProfile(CvFile cv, {required List<Skill> catalog}) async => raniProfile.copyWith(source: cv.source);

  @override
  Future<AnswerScore> gradeAnswer({required Job job, required InterviewQuestion question, required String answer}) async =>
      heuristic.gradeAnswer(answer);

  @override
  Future<GeneratedLetter> generateLetter({required Job job, required Profile profile, required LetterTone tone, required int variant}) async =>
      (text: coverLetter(job, profile, tone, variant), offline: false);
}

/// Gemini through Firebase AI Logic. Model names and the on/off switch come from Remote Config, so they can change
/// after the APK is submitted.
class GeminiAiService implements AiService {
  GeminiAiService({FirebaseRemoteConfig? config}) : _config = config ?? FirebaseRemoteConfig.instance;
  final FirebaseRemoteConfig _config;

  static const _timeout = Duration(seconds: 45);

  GenerativeModel _model(String key, {required double temperature, Schema? schema}) {
    if (!_config.getBool('ai_enabled')) throw AiFailure.disabled;
    return FirebaseAI.googleAI().generativeModel(
      model: _config.getString(key),
      generationConfig: GenerationConfig(temperature: temperature, responseMimeType: 'application/json', responseSchema: schema),
    );
  }

  Future<Map<String, Object?>> _json(GenerativeModel model, List<Part> parts) async {
    try {
      final res = await model.generateContent([Content.multi(parts)]).timeout(_timeout);
      return decodeJsonObject(res.text);
    } on AiFailure {
      rethrow;
    } on QuotaExceeded {
      throw AiFailure.quota;
    } on SocketException {
      throw AiFailure.network;
    } on TimeoutException {
      throw AiFailure.network;
    } catch (e) {
      debugPrint('Gemini: $e');
      final msg = '$e'.toLowerCase();
      if (msg.contains('quota') || msg.contains('429') || msg.contains('resource_exhausted')) throw AiFailure.quota;
      if (msg.contains('network') || msg.contains('socket') || msg.contains('host lookup')) throw AiFailure.network;
      throw AiFailure.invalid;
    }
  }

  static final _profileSchema = Schema.object(
    properties: {
      'name': Schema.string(),
      'level': Schema.enumString(enumValues: ['smaSmk', 'd3', 's1']),
      'major': Schema.string(),
      'school': Schema.string(),
      'city': Schema.string(),
      'skills': Schema.array(items: Schema.string()),
      'exps': Schema.array(
        items: Schema.object(
          properties: {
            'title': Schema.string(),
            'org': Schema.string(),
            'type': Schema.enumString(enumValues: ['kerja', 'magang', 'organisasi']),
            'months': Schema.integer(),
            'field': Schema.enumString(enumValues: jobFields),
            'desc': Schema.string(),
          },
        ),
      ),
    },
  );

  static final _gradeSchema = Schema.object(
    properties: {
      'relevansi': Schema.integer(),
      'struktur': Schema.integer(),
      'kejelasan': Schema.integer(),
      'bukti': Schema.integer(),
      'good': Schema.string(),
      'improve': Schema.string(),
      'better': Schema.string(),
    },
  );

  static final _letterSchema = Schema.object(properties: {'surat': Schema.string()});

  @override
  Future<Profile> extractProfile(CvFile cv, {required List<Skill> catalog}) async {
    final j = await _json(_model('ai_model_extract', temperature: 0.1, schema: _profileSchema), [
      TextPart(extractProfilePrompt(catalog)),
      InlineDataPart(cv.mimeType, cv.bytes),
    ]);
    return parseExtractedProfile(j, catalog: catalog, source: cv.source);
  }

  @override
  Future<AnswerScore> gradeAnswer({required Job job, required InterviewQuestion question, required String answer}) async {
    final prompt = gradeAnswerPrompt(job: job, question: question.text, questionType: question.type, answer: answer);
    return parseGrade(await _json(_model('ai_model_fast', temperature: 0.2, schema: _gradeSchema), [TextPart(prompt)]));
  }

  @override
  Future<GeneratedLetter> generateLetter({required Job job, required Profile profile, required LetterTone tone, required int variant}) async {
    final prompt = generateLetterPrompt(job: job, profile: profile, tone: tone, variant: variant, today: DateTime.now());
    final j = await _json(_model('ai_model_fast', temperature: 0.8, schema: _letterSchema), [TextPart(prompt)]);
    return (text: parseLetter(j, job: job), offline: false);
  }
}

/// Gemini first; grading and letters fall back to the local logic (marked offline) so a session or a letter
/// never dead-ends. CV extraction has no honest fallback, so its failure reaches the user with a retry.
class ResilientAiService implements AiService {
  const ResilientAiService(this._primary, [this._fallback = const OfflineAiService()]);
  final AiService _primary;
  final AiService _fallback;

  @override
  Future<Profile> extractProfile(CvFile cv, {required List<Skill> catalog}) => _primary.extractProfile(cv, catalog: catalog);

  @override
  Future<AnswerScore> gradeAnswer({required Job job, required InterviewQuestion question, required String answer}) async {
    try {
      return await _primary.gradeAnswer(job: job, question: question, answer: answer);
    } on AiFailure {
      return (await _fallback.gradeAnswer(job: job, question: question, answer: answer)).asOffline();
    }
  }

  @override
  Future<GeneratedLetter> generateLetter({required Job job, required Profile profile, required LetterTone tone, required int variant}) async {
    try {
      return await _primary.generateLetter(job: job, profile: profile, tone: tone, variant: variant);
    } on AiFailure {
      final l = await _fallback.generateLetter(job: job, profile: profile, tone: tone, variant: variant);
      return (text: l.text, offline: true);
    }
  }
}
