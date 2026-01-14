class ModelPricing {
  final double? prompt;
  final double? completion;

  const ModelPricing({this.prompt, this.completion});

  factory ModelPricing.fromMap(Map<String, dynamic>? m) {
    double? parse(dynamic v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    return ModelPricing(
      prompt: parse(m?['prompt']),
      completion: parse(m?['completion']),
    );
  }
}

class CostCalculator {
  const CostCalculator();

  double? calcCost({
    required bool pricedAsVseGpt,
    required ModelPricing pricing,
    required int promptTokens,
    required int completionTokens,
    double? totalCostFromApi,
  }) {
    // OpenRouter часто отдаёт готовую total_cost
    if (!pricedAsVseGpt && totalCostFromApi != null) {
      return totalCostFromApi;
    }

    final pr = pricing.prompt;
    final cr = pricing.completion;
    if (pr == null && cr == null) return null;

    final promptRate = pr ?? 0.0;
    final completionRate = cr ?? 0.0;

    if (pricedAsVseGpt) {
      // ₽/K
      return (promptTokens / 1000.0) * promptRate +
          (completionTokens / 1000.0) * completionRate;
    }

    // $/token
    return (promptTokens * promptRate) + (completionTokens * completionRate);
  }

  double? tryParseDouble(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  int? normTokens(dynamic v) {
    final t = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '');
    if (t == null || t <= 0) return null;
    return t;
  }
}
