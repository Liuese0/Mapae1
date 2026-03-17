/// Mapae 앱 전용 예외 클래스 계층.
///
/// 서비스 레이어에서 발생하는 모든 예외를 [AppException]으로 래핑하여
/// UI에서 에러 코드 기반으로 사용자 메시지를 표시할 수 있도록 합니다.
sealed class AppException implements Exception {
  final String code;
  final String debugMessage;
  final Object? originalError;

  const AppException({
    required this.code,
    required this.debugMessage,
    this.originalError,
  });

  @override
  String toString() => '$runtimeType($code): $debugMessage';
}

/// 인증 관련 예외
class AuthException extends AppException {
  const AuthException({
    required super.code,
    required super.debugMessage,
    super.originalError,
  });

  // 팩토리 상수
  factory AuthException.notLoggedIn() => const AuthException(
    code: 'auth_not_logged_in',
    debugMessage: 'User is not logged in',
  );

  factory AuthException.signUpFailed(Object error) => AuthException(
    code: 'auth_sign_up_failed',
    debugMessage: 'Sign up failed: $error',
    originalError: error,
  );

  factory AuthException.signInFailed(Object error) => AuthException(
    code: 'auth_sign_in_failed',
    debugMessage: 'Sign in failed: $error',
    originalError: error,
  );

  factory AuthException.googleCancelled() => const AuthException(
    code: 'auth_google_cancelled',
    debugMessage: 'Google sign-in was cancelled',
  );

  factory AuthException.googleTokenMissing() => const AuthException(
    code: 'auth_google_token_missing',
    debugMessage: 'Google ID token is null',
  );
}

/// 네트워크/서버 관련 예외
class NetworkException extends AppException {
  const NetworkException({
    required super.code,
    required super.debugMessage,
    super.originalError,
  });

  factory NetworkException.timeout() => const NetworkException(
    code: 'network_timeout',
    debugMessage: 'Request timed out',
  );

  factory NetworkException.serverError(Object error) => NetworkException(
    code: 'network_server_error',
    debugMessage: 'Server error: $error',
    originalError: error,
  );
}

/// 데이터/비즈니스 로직 관련 예외
class DataException extends AppException {
  const DataException({
    required super.code,
    required super.debugMessage,
    super.originalError,
  });

  factory DataException.notFound(String entity) => DataException(
    code: 'data_not_found',
    debugMessage: '$entity not found',
  );

  factory DataException.operationFailed(String operation, Object error) =>
      DataException(
        code: 'data_operation_failed',
        debugMessage: '$operation failed: $error',
        originalError: error,
      );

  factory DataException.duplicateFound() => const DataException(
    code: 'data_duplicate',
    debugMessage: 'Duplicate entry found',
  );
}

/// 스토리지 관련 예외
class StorageException extends AppException {
  const StorageException({
    required super.code,
    required super.debugMessage,
    super.originalError,
  });

  factory StorageException.uploadFailed(Object error) => StorageException(
    code: 'storage_upload_failed',
    debugMessage: 'File upload failed: $error',
    originalError: error,
  );
}