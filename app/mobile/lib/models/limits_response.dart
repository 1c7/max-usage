/// `jsonDecode` always yields `Map<String, dynamic>` for a JSON object, but a `Map` value can
/// arrive with a looser static type from other sources (e.g. a Dart map literal in a test) — this
/// copies rather than force-casts so a real object is never rejected on its runtime map type.
Map<String, dynamic> _asStringMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

/// Parses the `openusage.limits.v1` response served by the Mac's LAN Sync API
/// (see `docs/lan-sync.md` and `docs/local-http-api.md` in the main app repo).
class LimitsResponse {
  final DateTime generatedAt;
  final Map<String, ProviderLimits> providers;
  final List<LimitsError> errors;

  LimitsResponse({
    required this.generatedAt,
    required this.providers,
    required this.errors,
  });

  factory LimitsResponse.fromJson(Map<String, dynamic> json) {
    final providersJson = _asStringMap(json['providers']);
    final errorsJson = (json['errors'] as List<dynamic>?) ?? [];
    return LimitsResponse(
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      providers: providersJson.map(
        (id, value) => MapEntry(id, ProviderLimits.fromJson(id, _asStringMap(value))),
      ),
      errors: errorsJson.map((e) => LimitsError.fromJson(_asStringMap(e))).toList(),
    );
  }
}

class LimitsError {
  final String providerId;
  final String message;

  LimitsError({required this.providerId, required this.message});

  factory LimitsError.fromJson(Map<String, dynamic> json) => LimitsError(
    providerId: json['providerId'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );
}

class ProviderLimits {
  final String id;
  final String displayName;
  final String? plan;
  final bool stale;
  final Map<String, ResourceLimit> resources;

  ProviderLimits({
    required this.id,
    required this.displayName,
    this.plan,
    required this.stale,
    required this.resources,
  });

  factory ProviderLimits.fromJson(String id, Map<String, dynamic> json) {
    final resourcesJson = _asStringMap(json['resources']);
    return ProviderLimits(
      id: id,
      displayName: json['displayName'] as String? ?? id,
      plan: json['plan'] as String?,
      stale: json['stale'] as bool? ?? false,
      resources: resourcesJson.map(
        (key, value) => MapEntry(key, ResourceLimit.fromJson(key, _asStringMap(value))),
      ),
    );
  }
}

/// One resource row (`kind` is `"consumption"`, with `used`/`limit`/`utilization`, or
/// `"balance"`, with just `available`) — see the wire shape documented in `local-http-api.md`.
class ResourceLimit {
  final String key;
  final String kind;
  final String unit;
  final double? used;
  final double? limit;
  final double? remaining;
  final double? utilization;
  final double? available;

  ResourceLimit({
    required this.key,
    required this.kind,
    required this.unit,
    this.used,
    this.limit,
    this.remaining,
    this.utilization,
    this.available,
  });

  factory ResourceLimit.fromJson(String key, Map<String, dynamic> json) {
    double? asDouble(dynamic value) =>
        value == null ? null : (value as num).toDouble();
    return ResourceLimit(
      key: key,
      kind: json['kind'] as String? ?? 'consumption',
      unit: json['unit'] as String? ?? '',
      used: asDouble(json['used']),
      limit: asDouble(json['limit']),
      remaining: asDouble(json['remaining']),
      utilization: asDouble(json['utilization']),
      available: asDouble(json['available']),
    );
  }

  /// `"geminiSession"` -> `"Gemini Session"`. The API keys resources by stable camelCase IDs,
  /// not display labels, so this is a best-effort readable fallback rather than a translation.
  String get label {
    if (key.isEmpty) return key;
    final buffer = StringBuffer();
    for (var i = 0; i < key.length; i++) {
      final char = key[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (i == 0) {
        buffer.write(char.toUpperCase());
      } else if (isUpper) {
        buffer.write(' ');
        buffer.write(char);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
