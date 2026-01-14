part of 'chat_provider.dart';

class ModelUsage {
  final int requests; // кол-во ответов модели (обычно = кол-во запросов)
  final int tokens;
  final double cost;

  const ModelUsage({
    required this.requests,
    required this.tokens,
    required this.cost,
  });
}

class DailySpend {
  final DateTime day; // дата без времени
  final double cost;

  const DailySpend({
    required this.day,
    required this.cost,
  });
}

class DailyAggregate {
  final DateTime day; // дата без времени
  final int requests;
  final int tokens;
  final double cost;

  const DailyAggregate({
    required this.day,
    required this.requests,
    required this.tokens,
    required this.cost,
  });
}

// Основной класс провайдера для управления состоянием чата
