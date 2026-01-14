enum ModelSortKey { cost, name, context }

enum ModelSortDir { asc, desc }

double _tryParseDouble(dynamic v) {
  if (v == null) return double.nan;
  return double.tryParse(v.toString()) ?? double.nan;
}

int _tryParseInt(dynamic v) {
  if (v == null) return 0;
  return int.tryParse(v.toString()) ?? 0;
}

/// "Unit cost" для сортировки: prompt + completion.
/// Если цен нет — считаем Infinity (пусть улетает вниз при asc).
double modelUnitCost(Map<String, dynamic> m) {
  final pricing = (m['pricing'] is Map) ? (m['pricing'] as Map) : const {};
  final pr = _tryParseDouble(pricing['prompt']);
  final cr = _tryParseDouble(pricing['completion']);

  final hasAny = pr.isFinite || cr.isFinite;
  if (!hasAny) return double.infinity;

  return (pr.isFinite ? pr : 0.0) + (cr.isFinite ? cr : 0.0);
}

String modelNameForSort(Map<String, dynamic> m) {
  final name = (m['name']?.toString().trim() ?? '');
  final id = (m['id']?.toString().trim() ?? '');
  return (name.isNotEmpty ? name : id).toLowerCase();
}

int modelContextLen(Map<String, dynamic> m) {
  return _tryParseInt(m['context_length']);
}

List<Map<String, dynamic>> sortModels(
  List<Map<String, dynamic>> models, {
  required ModelSortKey key,
  required ModelSortDir dir,
}) {
  final out = List<Map<String, dynamic>>.from(models);

  int sign(int v) => dir == ModelSortDir.asc ? v : -v;

  int cmpDouble(double a, double b) {
    if (a == b) return 0;
    return a < b ? -1 : 1;
  }

  out.sort((a, b) {
    int r;

    switch (key) {
      case ModelSortKey.cost:
        r = cmpDouble(modelUnitCost(a), modelUnitCost(b));
        break;
      case ModelSortKey.name:
        r = modelNameForSort(a).compareTo(modelNameForSort(b));
        break;
      case ModelSortKey.context:
        r = modelContextLen(a).compareTo(modelContextLen(b));
        break;
    }

    // tie-breaker, чтобы список не "дёргался"
    if (r == 0) {
      r = modelNameForSort(a).compareTo(modelNameForSort(b));
      if (r == 0) {
        final ida = a['id']?.toString() ?? '';
        final idb = b['id']?.toString() ?? '';
        r = ida.compareTo(idb);
      }
    }

    return sign(r);
  });

  return out;
}
