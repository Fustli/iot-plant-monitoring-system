/// Custom exception classes for API error handling
/// Provides structured error information for UI display and debugging

/// Base class for all API-related exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;
  final dynamic originalError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.details,
    this.originalError,
  });

  /// Get user-friendly message in Hungarian
  String get messageHu {
    switch (statusCode) {
      case 401:
        return 'Hibás bejelentkezési adatok. Kérjük, ellenőrizze az email címet és jelszót.';
      case 403:
        return 'Nincs jogosultsága ehhez a művelethez.';
      case 404:
        return 'A keresett elem nem található.';
      case 422:
        return 'Érvénytelen adatok. Kérjük, ellenőrizze a megadott információkat.';
      case 500:
        return 'Szerverhiba történt. Kérjük, próbálja újra később.';
      case 503:
        return 'A szolgáltatás ideiglenesen nem elérhető.';
      default:
        return message;
    }
  }

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Network-related exceptions (no internet, timeout, etc.)
class NetworkException extends ApiException {
  const NetworkException({
    super.message = 'Hálózati hiba. Ellenőrizze az internetkapcsolatot.',
    super.originalError,
  });

  @override
  String get messageHu => 'Hálózati hiba. Ellenőrizze az internetkapcsolatot.';
}

/// Server unreachable exception
class ServerUnreachableException extends ApiException {
  const ServerUnreachableException({
    super.message = 'A szerver nem elérhető. Kérjük, próbálja újra később.',
    super.originalError,
  });

  @override
  String get messageHu => 'A szerver nem elérhető. A háttérrendszer fut?';
}

/// Authentication exception (401)
class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message = 'Azonosítás szükséges. Kérjük, jelentkezzen be újra.',
    super.statusCode = 401,
  });

  @override
  String get messageHu => 'Lejárt munkamenet. Kérjük, jelentkezzen be újra.';
}

/// Authorization exception (403)
class ForbiddenException extends ApiException {
  const ForbiddenException({
    super.message = 'Nincs jogosultsága ehhez a művelethez.',
    super.statusCode = 403,
  });

  @override
  String get messageHu => 'Nincs jogosultsága ehhez a művelethez.';
}

/// Not found exception (404)
class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = 'A keresett elem nem található.',
    super.statusCode = 404,
  });

  @override
  String get messageHu => 'A keresett elem nem található.';
}

/// Validation exception (422)
class ValidationException extends ApiException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    super.message = 'Érvénytelen adatok.',
    super.statusCode = 422,
    this.fieldErrors,
    super.details,
  });

  @override
  String get messageHu {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      final errorMessages = fieldErrors!.entries
          .map((e) => '${e.key}: ${e.value.join(', ')}')
          .join('\n');
      return 'Hibás mezők:\n$errorMessages';
    }
    return 'Érvénytelen adatok. Kérjük, ellenőrizze a megadott információkat.';
  }
}

/// Server error exception (500)
class ServerException extends ApiException {
  const ServerException({
    super.message = 'Szerverhiba történt.',
    super.statusCode = 500,
    super.details,
  });

  @override
  String get messageHu => 'Szerverhiba történt. Kérjük, próbálja újra később.';
}

/// IoT device communication exception
class DeviceCommunicationException extends ApiException {
  final String? deviceId;

  const DeviceCommunicationException({
    super.message = 'Nem sikerült kommunikálni az eszközzel.',
    this.deviceId,
    super.originalError,
  });

  @override
  String get messageHu =>
      'Az IoT eszköz nem elérhető. Ellenőrizze az eszköz kapcsolatát.';
}

/// Timeout exception
class TimeoutException extends ApiException {
  const TimeoutException({
    super.message = 'A kérés időtúllépés miatt megszakadt.',
    super.originalError,
  });

  @override
  String get messageHu => 'A kérés túl sokáig tartott. Kérjük, próbálja újra.';
}

/// Result wrapper for API calls
/// Provides a type-safe way to handle success/failure
class ApiResult<T> {
  final T? data;
  final ApiException? error;
  final bool isSuccess;

  const ApiResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  /// Create a successful result
  factory ApiResult.success(T data) => ApiResult._(
        data: data,
        isSuccess: true,
      );

  /// Create a failed result
  factory ApiResult.failure(ApiException error) => ApiResult._(
        error: error,
        isSuccess: false,
      );

  /// Get data or throw exception
  T get dataOrThrow {
    if (isSuccess && data != null) return data as T;
    throw error ?? const ApiException(message: 'Unknown error');
  }

  /// Map the result to another type
  ApiResult<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      return ApiResult.success(mapper(data as T));
    }
    return ApiResult.failure(
        error ?? const ApiException(message: 'Unknown error'));
  }

  /// Handle both success and failure cases
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(ApiException error) onFailure,
  }) {
    if (isSuccess && data != null) {
      return onSuccess(data as T);
    }
    return onFailure(error ?? const ApiException(message: 'Unknown error'));
  }
}
