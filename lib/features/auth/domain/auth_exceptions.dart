// AuthException - исключения для модуля авторизации
//
// Используется для обработки ошибок в процессе авторизации:
// - Неверный формат API ключа
// - Неавторизованный доступ
// - Проблемы с сетью
// - Некорректный ответ от API
// - Неизвестные ошибки

/// Коды ошибок авторизации
enum AuthErrorCode {
  /// Неверный формат API ключа (не распознан провайдер)
  invalidKeyFormat,
  /// Неавторизованный доступ (неверный PIN или ключ)
  unauthorized,
  /// Проблемы с сетью (таймаут, нет соединения)
  network,
  /// Некорректный ответ от API (неожиданный формат)
  badResponse,
  /// Неизвестная ошибка
  unknown,
}

/// Исключение для ошибок авторизации
/// 
/// Содержит код ошибки и человекочитаемое сообщение для отображения пользователю
class AuthException implements Exception {
  final AuthErrorCode code;
  final String message;
  
  AuthException(this.code, this.message);

  @override
  String toString() => message;
}
