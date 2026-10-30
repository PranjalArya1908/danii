import 'dart:convert';
import 'dart:io';
import '../models/models.dart';

/// Structured prediction result from Gemini AI Safety Intelligence
class GeminiCheckInPrediction {
  final int recommendedIntervalMinutes;
  final String safetyTier;
  final String rationale;
  final String crowdContext;
  final List<String> safetyTips;
  final bool isAiGenerated;

  const GeminiCheckInPrediction({
    required this.recommendedIntervalMinutes,
    required this.safetyTier,
    required this.rationale,
    required this.crowdContext,
    this.safetyTips = const [],
    this.isAiGenerated = false,
  });

  factory GeminiCheckInPrediction.fromJson(Map<String, dynamic> json, {bool isAi = true}) {
    final int interval = (json['intervalMinutes'] as num?)?.toInt() ?? 10;
    // Snap to supported intervals: 5, 10, or 20
    final snappedInterval = interval <= 7 ? 5 : (interval >= 15 ? 20 : 10);

    final rawTier = (json['tier'] as String?)?.trim() ?? 'Balanced';
    final normalizedTier = rawTier.toLowerCase().contains('high')
        ? 'High Alert'
        : (rawTier.toLowerCase().contains('relax') ? 'Relaxed' : 'Balanced');

    final rawRationale = (json['rationale'] as String?)?.trim() ??
        'Adaptive check-in frequency matched to your route and travel mode.';

    final rawContext = (json['crowdContext'] as String?)?.trim() ?? 'Urban Corridor';

    List<String> tips = [];
    if (json['safetyTips'] is List) {
      tips = (json['safetyTips'] as List).map((e) => e.toString().trim()).toList();
    }

    return GeminiCheckInPrediction(
      recommendedIntervalMinutes: snappedInterval,
      safetyTier: normalizedTier,
      rationale: rawRationale,
      crowdContext: rawContext,
      safetyTips: tips,
      isAiGenerated: isAi,
    );
  }
}

/// Service providing Google Gemini AI predictions for adaptive safety check-ins
/// and contextual safety briefings. Supports runtime API key configuration with
/// seamless fallback to local intelligence when offline or before an API key is provided.
class GeminiSafetyService {
  static String? _customApiKey;
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  /// Configures or updates the Gemini API key at runtime.
  static void setApiKey(String key) {
    _customApiKey = key.trim();
  }

  /// Gets the active API key (from runtime config or compile-time environment).
  static String get apiKey {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey!;
    }
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  /// Whether an API key has been configured.
  static bool get hasApiKey => apiKey.isNotEmpty;

  /// Predicts adaptive check-in interval and contextual safety tier using Gemini AI.
  /// Falls back smoothly to local intelligence if no API key is set or upon network failure.
  static Future<GeminiCheckInPrediction> predictCheckIn({
    required TransportMode mode,
    required double distanceKm,
    required String startAddress,
    required String destinationAddress,
    DateTime? time,
  }) async {
    final journeyTime = time ?? DateTime.now();

    if (!hasApiKey) {
      return _fallbackHeuristicPrediction(
        mode: mode,
        distanceKm: distanceKm,
        journeyTime: journeyTime,
      );
    }

    try {
      final hour = journeyTime.hour;
      final minute = journeyTime.minute.toString().padLeft(2, '0');
      final prompt = '''
Analyze this woman transit journey for personal safety check-in scheduling:
- Transport Mode: ${mode.label}
- Distance: ${distanceKm.toStringAsFixed(1)} km
- Departure Time: $hour:$minute
- Origin: ${startAddress.isNotEmpty ? startAddress : "City Center"}
- Destination: ${destinationAddress.isNotEmpty ? destinationAddress : "Destination"}

Respond ONLY with a JSON object matching this schema without markdown code blocks:
{
  "intervalMinutes": 5, 10, or 20,
  "tier": "High Alert", "Balanced", or "Relaxed",
  "rationale": "One concise, calm, professional sentence explaining the recommendation without emojis.",
  "crowdContext": "2 to 4 words describing the setting, e.g. Night Street Walking or Lit Main Arterial",
  "safetyTips": ["Brief safety observation 1", "Brief safety observation 2"]
}
''';

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      );

      final request = await _httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.2,
        }
      });

      request.add(utf8.encode(requestBody));
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.isNotEmpty) {
              final parsedJson = jsonDecode(text);
              if (parsedJson is Map<String, dynamic>) {
                return GeminiCheckInPrediction.fromJson(parsedJson, isAi: true);
              }
            }
          }
        }
      }
    } catch (_) {
      // Seamlessly fallback to local heuristic model on any error
    }

    return _fallbackHeuristicPrediction(
      mode: mode,
      distanceKm: distanceKm,
      journeyTime: journeyTime,
    );
  }

  /// Generates route safety advice or contextual safety briefing.
  static Future<String?> generateSafetyBriefing({
    required TransportMode mode,
    required String startAddress,
    required String destinationAddress,
  }) async {
    if (!hasApiKey) return null;

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      );

      final prompt = 'Provide 2 concise, human, practical safety precautions for a woman traveling by ${mode.label} from $startAddress to $destinationAddress at night. No markdown bolding, no emojis, professional tone.';

      final request = await _httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 120,
        }
      })));

      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// High-precision, zero-latency local heuristic model based on empirical transit safety criteria.
  static GeminiCheckInPrediction _fallbackHeuristicPrediction({
    required TransportMode mode,
    required double distanceKm,
    required DateTime journeyTime,
  }) {
    final hour = journeyTime.hour;
    final isNight = hour >= 21 || hour < 5;
    final isEvening = hour >= 18 && hour < 21;

    // 1. Walking: Exposed outdoors
    if (mode == TransportMode.walking) {
      return GeminiCheckInPrediction(
        recommendedIntervalMinutes: 5,
        safetyTier: 'High Alert',
        rationale: isNight
            ? 'Night walking route requires frequent check-ins for active guardian monitoring.'
            : (isEvening
                ? 'Dusk foot transit armed with 5-minute safety intervals.'
                : 'Pedestrian routes maintain 5-minute intervals for continuous escort safety.'),
        crowdContext: 'Pedestrian Transit',
        safetyTips: const [
          'Stay on well-lit thoroughfares and keep phone accessible.',
          'Guardians receive instant alerts if check-in is unacknowledged.'
        ],
        isAiGenerated: false,
      );
    }

    // 2. Metro: Secured with station security & dense public presence
    if (mode == TransportMode.metro) {
      return const GeminiCheckInPrediction(
        recommendedIntervalMinutes: 20,
        safetyTier: 'Relaxed',
        rationale: 'Station security and high passenger density permit relaxed 20-minute check-ins.',
        crowdContext: 'Secured Metro Line',
        safetyTips: [
          'Metro stations feature security personnel and surveillance.',
          'Check-ins reset seamlessly upon arrival.'
        ],
        isAiGenerated: false,
      );
    }

    // 3. Long Highway / Suburban stretch (> 45 km)
    if (distanceKm > 45) {
      if (isNight) {
        return const GeminiCheckInPrediction(
          recommendedIntervalMinutes: 5,
          safetyTier: 'High Alert',
          rationale: 'Night highway corridors use 5-minute check-ins across isolated route segments.',
          crowdContext: 'Isolated Highway',
          safetyTips: [
            'Live GPS corridor tracking verifies continuous forward motion.',
            'Route deviations trigger automatic contact warnings.'
          ],
          isAiGenerated: false,
        );
      } else {
        return const GeminiCheckInPrediction(
          recommendedIntervalMinutes: 10,
          safetyTier: 'Balanced',
          rationale: 'Intercity corridor transit calibrated to balanced 10-minute intervals.',
          crowdContext: 'Intercity Highway',
          safetyTips: [
            'Maintain corridor tracking enabled for highway transit.',
            'Regular interval pings assure your trusted circle.'
          ],
          isAiGenerated: false,
        );
      }
    }

    // 4. Night Cab / Auto
    if (isNight) {
      return const GeminiCheckInPrediction(
        recommendedIntervalMinutes: 5,
        safetyTier: 'High Alert',
        rationale: 'Night ride monitoring active with 5-minute check-ins for verified driver accountability.',
        crowdContext: 'Night Vehicle Ride',
        safetyTips: [
          'Ensure vehicle registration matches your designated driver.',
          'Corridor geofence will detect unexpected detours.'
        ],
        isAiGenerated: false,
      );
    }

    // 5. Evening Cab / Auto
    if (isEvening) {
      if (distanceKm > 15) {
        return const GeminiCheckInPrediction(
          recommendedIntervalMinutes: 5,
          safetyTier: 'High Alert',
          rationale: 'Extended evening routes utilize 5-minute intervals as lighting decreases.',
          crowdContext: 'Suburban Transit',
          safetyTips: [
            'Vehicle route is continuously tracked against corridor limits.',
            'One-tap check-in resets the protection interval.'
          ],
          isAiGenerated: false,
        );
      } else {
        return const GeminiCheckInPrediction(
          recommendedIntervalMinutes: 10,
          safetyTier: 'Balanced',
          rationale: 'Evening urban transit uses balanced 10-minute intervals along main roads.',
          crowdContext: 'Urban Arterial',
          safetyTips: [
            'City arterial corridors provide consistent cellular coverage.',
            'Silent check-ins minimize interruption.'
          ],
          isAiGenerated: false,
        );
      }
    }

    // 6. Public Bus in daytime
    if (mode == TransportMode.bus) {
      return const GeminiCheckInPrediction(
        recommendedIntervalMinutes: 10,
        safetyTier: 'Balanced',
        rationale: 'Public bus transit operates with balanced 10-minute check-in intervals.',
        crowdContext: 'Public Transit Bus',
        safetyTips: [
          'Public buses offer community presence along scheduled routes.',
          'Alerts remain silent unless unacknowledged.'
        ],
        isAiGenerated: false,
      );
    }

    // 7. Daytime Cab / Auto
    return const GeminiCheckInPrediction(
      recommendedIntervalMinutes: 10,
      safetyTier: 'Balanced',
      rationale: 'Daylight urban transit calibrated to balanced 10-minute check-ins.',
      crowdContext: 'City Traffic',
      safetyTips: [
        'Live telemetry tracks your route progress in real-time.',
        'Trusted circle can view route status if needed.'
      ],
      isAiGenerated: false,
    );
  }
}

