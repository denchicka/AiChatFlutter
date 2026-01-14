class ModelUsage {
  final int requests;
  final int tokens;
  final double cost;

  const ModelUsage({
    required this.requests,
    required this.tokens,
    required this.cost,
  });
}

class DailySpend {
  final DateTime day;
  final double cost;

  const DailySpend({
    required this.day,
    required this.cost,
  });
}

class DailyAggregate {
  final DateTime day;
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
