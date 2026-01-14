part of 'chat_screen.dart';

class _ModelPickerSheet extends StatefulWidget {
  final List<dynamic> models;
  final String? currentId;

  final bool initialFreeOnly;
  final ValueChanged<bool> onFreeOnlyChanged;

  const _ModelPickerSheet({
    required this.models,
    required this.currentId,
    required this.initialFreeOnly,
    required this.onFreeOnlyChanged,
  });

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.tertiary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SpecChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  final _controller = TextEditingController();
  bool _freeOnly = false;
  String _q = '';
  ModelSortKey _sortKey = ModelSortKey.cost;
  ModelSortDir _sortDir = ModelSortDir.desc;
  bool _hideUnknownPrice = false; // скрывать модели без цены
  double? _maxPrice; // потолок цены (по prompt/completion)
  RangeValues? _ctxRange; // диапазон контекста

  int? _parseCtx(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  @override
  void initState() {
    super.initState();
    _freeOnly = widget.initialFreeOnly;

    _controller.addListener(() {
      setState(() => _q = _controller.text);
    });
  }

  void _toggleDir() {
    setState(() {
      _sortDir =
          _sortDir == ModelSortDir.desc ? ModelSortDir.asc : ModelSortDir.desc;
    });
  }

  Future<void> _openFiltersDialog() async {
    // Соберём диапазон контекста по всем моделям
    final all = <Map<String, dynamic>>[];
    for (final raw in widget.models) {
      if (raw is Map) all.add(Map<String, dynamic>.from(raw));
    }

    final ctxVals = all
        .map((m) => _parseCtx(m['context_length']))
        .whereType<int>()
        .toList();

    final int ctxMin = ctxVals.isEmpty ? 0 : ctxVals.reduce(math.min);
    final int ctxMax = ctxVals.isEmpty ? 0 : ctxVals.reduce(math.max);

    final priceVals = all
        .expand((m) => [
              _parsePrice(m['pricing']?['prompt']),
              _parsePrice(m['pricing']?['completion']),
            ])
        .where((v) => v.isFinite)
        .toList();

    final double priceMax =
        priceVals.isEmpty ? 2.0 : priceVals.reduce(math.max).clamp(0.1, 50.0);

    // Локальные состояния диалога (копии текущих фильтров)
    bool hideUnknown = _hideUnknownPrice;

    bool priceCapEnabled = _maxPrice != null;
    double maxPriceValue =
        (_maxPrice ?? math.min(1.0, priceMax)).clamp(0.0, priceMax);

    final fullCtx = RangeValues(ctxMin.toDouble(), ctxMax.toDouble());
    RangeValues ctx = _ctxRange ?? fullCtx;

    String fmtPrice(double v) => v.toStringAsFixed(v < 1 ? 2 : 1);

    final res = await showDialog<bool>(
      context: context,
      builder: (ctxDialog) {
        final scheme = Theme.of(ctxDialog).colorScheme;

        SliderThemeData niceSliderTheme(BuildContext c) {
          final cs = Theme.of(c).colorScheme;
          return SliderTheme.of(c).copyWith(
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 9),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            inactiveTrackColor: cs.outlineVariant.withValues(alpha: 0.45),
            valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
            valueIndicatorColor: cs.primary,
            valueIndicatorTextStyle: TextStyle(
              color: cs.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          );
        }

        return StatefulBuilder(
          builder: (ctxDialog, setLocal) {
            return AlertDialog(
              backgroundColor: scheme.surfaceContainerHighest,
              title: const Text('Фильтры'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Скрывать модели без цены'),
                        value: hideUnknown,
                        onChanged: (v) => setLocal(() => hideUnknown = v),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Лимит цены'),
                        subtitle: Text(
                          priceCapEnabled
                              ? '≤ ${fmtPrice(maxPriceValue)}'
                              : 'Без ограничения',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        value: priceCapEnabled,
                        onChanged: (v) => setLocal(() {
                          priceCapEnabled = v;
                          if (!v) {
                            maxPriceValue =
                                math.min(1.0, priceMax).clamp(0.0, priceMax);
                          }
                        }),
                      ),
                      if (priceCapEnabled) ...[
                        SliderTheme(
                          data: niceSliderTheme(ctxDialog),
                          child: Slider(
                            min: 0.0,
                            max: priceMax,
                            divisions: 20,
                            label: '≤ ${fmtPrice(maxPriceValue)}',
                            value: maxPriceValue,
                            onChanged: (v) => setLocal(() => maxPriceValue = v),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (ctxMax > ctxMin) ...[
                        Text(
                          'Контекст: ${ctx.start.round()}–${ctx.end.round()}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: niceSliderTheme(ctxDialog),
                          child: RangeSlider(
                            min: fullCtx.start,
                            max: fullCtx.end,
                            values: ctx,
                            divisions: (ctxMax - ctxMin).clamp(2, 24).toInt(),
                            labels: RangeLabels(
                              ctx.start.round().toString(),
                              ctx.end.round().toString(),
                            ),
                            onChanged: (v) => setLocal(() => ctx = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setLocal(() {
                      hideUnknown = false;

                      priceCapEnabled = false;
                      maxPriceValue =
                          math.min(1.0, priceMax).clamp(0.0, priceMax);

                      ctx = fullCtx;
                    });
                  },
                  child: const Text('Сбросить'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctxDialog).pop(true),
                  child: const Text('Готово'),
                ),
              ],
            );
          },
        );
      },
    );

    if (res == true) {
      // Сохраняем фильтры. Важно: "полный" контекст не считаем фильтром => null
      final ctxIsFull = (ctxMax <= ctxMin) ||
          ((ctx.start - fullCtx.start).abs() < 0.5 &&
              (ctx.end - fullCtx.end).abs() < 0.5);

      setState(() {
        _hideUnknownPrice = hideUnknown;
        _maxPrice = priceCapEnabled ? maxPriceValue : null;
        _ctxRange = ctxIsFull ? null : ctx;
      });
    }
  }

  Widget _buildSortRow(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<ModelSortKey>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ModelSortKey.cost,
                label: Text('Цена', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.attach_money_rounded, size: 18),
              ),
              ButtonSegment(
                value: ModelSortKey.context,
                label: Text('Контекст', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.memory_rounded, size: 18),
              ),
              ButtonSegment(
                value: ModelSortKey.name,
                label: Text('A–Я', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.sort_by_alpha_rounded, size: 18),
              ),
            ],
            selected: <ModelSortKey>{_sortKey},
            onSelectionChanged: (s) => setState(() => _sortKey = s.first),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurfaceVariant,
              selectedBackgroundColor: scheme.primary.withValues(alpha: 0.14),
              selectedForegroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip:
              _sortDir == ModelSortDir.asc ? 'По возрастанию' : 'По убыванию',
          onPressed: _toggleDir,
          icon: Icon(
            _sortDir == ModelSortDir.asc
                ? Icons.south_rounded
                : Icons.north_rounded,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _filtersButton() {
    final hasFilters =
        _hideUnknownPrice || _maxPrice != null || _ctxRange != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(
          tooltip: 'Фильтры',
          onPressed: _openFiltersDialog,
          icon: const Icon(Icons.tune),
        ),
        if (hasFilters)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchRow(ColorScheme scheme, bool isVseGpt) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
              hintText: 'Поиск модели...',
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Кнопка фильтров (общая)
        _filtersButton(),

        if (!isVseGpt) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Только FREE',
            onPressed: () {
              final next = !_freeOnly;
              setState(() => _freeOnly = next);
              widget.onFreeOnlyChanged(next);
            },
            icon:
                Icon(_freeOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
          ),
        ],
      ],
    );
  }

  Widget _buildModelTile(Map<String, dynamic> m) {
    final scheme = Theme.of(context).colorScheme;
    final isVseGpt = context.read<ChatProvider>().isVseGpt;

    final id = (m['id'] ?? '').toString();
    final name = (m['name'] ?? id).toString();
    final selected = id == widget.currentId;

    final prompt = _parsePrice(m['pricing']?['prompt']);
    final completion = _parsePrice(m['pricing']?['completion']);
    final ctx = (m['context_length'] ?? '0').toString();

    final isFree = (prompt == 0.0 && completion == 0.0);
    final showFree = !isVseGpt && isFree;
    final chat = context.read<ChatProvider>();

    String priceText(double v) {
      if (!v.isFinite) return '—';
      if (!isVseGpt && v == 0.0) return '0';
      return chat.formatPricing(v);
    }

    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primary.withValues(alpha: 0.10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (!isVseGpt && isFree) _Badge(text: 'FREE'),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SpecChip(
                  icon: Icons.arrow_upward,
                  text: (!isVseGpt && showFree) ? 'FREE' : priceText(prompt),
                ),
                _SpecChip(
                  icon: Icons.arrow_downward,
                  text:
                      (!isVseGpt && showFree) ? 'FREE' : priceText(completion),
                ),
                _SpecChip(icon: Icons.memory, text: ctx),
              ],
            ),
          ],
        ),
      ),
      onTap: () => Navigator.of(context).pop<String>(id),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _parsePrice(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    return d ?? double.nan; // неизвестно => NaN, а не 0
  }

  bool _isFree(Map<String, dynamic> m) {
    final prompt = _parsePrice(m['pricing']?['prompt']);
    final completion = _parsePrice(m['pricing']?['completion']);
    return prompt.isFinite &&
        completion.isFinite &&
        prompt == 0.0 &&
        completion == 0.0;
  }

  List<Map<String, dynamic>> _filtered() {
    final isVseGpt = context.read<ChatProvider>().isVseGpt;

    final q = _q.trim().toLowerCase();

    final list = <Map<String, dynamic>>[];
    for (final raw in widget.models) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final prompt = _parsePrice(m['pricing']?['prompt']);
      final completion = _parsePrice(m['pricing']?['completion']);
      final ctx = _parseCtx(m['context_length']);

      if (_hideUnknownPrice) {
        if (!prompt.isFinite || !completion.isFinite) continue;
      }

      if (_maxPrice != null) {
        if (prompt.isFinite && completion.isFinite) {
          if (prompt > _maxPrice! || completion > _maxPrice!) continue;
        } else {
          // нет цены — НЕ выкидываем, если hideUnknownPrice выключен
        }
      }

      if (_ctxRange != null && ctx != null) {
        if (ctx < _ctxRange!.start || ctx > _ctxRange!.end) continue;
      }

      if (!isVseGpt) {
        if (_freeOnly && !_isFree(m)) continue;
      }

      if (q.isNotEmpty) {
        final name = (m['name'] ?? '').toString().toLowerCase();
        final id = (m['id'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !id.contains(q)) continue;
      }
      list.add(m);
    }
    return sortModels(
      list,
      key: _sortKey,
      dir: _sortDir,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isVseGpt = context.watch<ChatProvider>().isVseGpt;
    final models = _filtered();

    final sheetH = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      child: SizedBox(
        height: sheetH,
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max, // КЛЮЧ
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchRow(scheme, isVseGpt),
              const SizedBox(height: 10),

              // Сортировка (см. пункт 2 ниже)
              _buildSortRow(scheme),
              const SizedBox(height: 10),

              Expanded(
                // КЛЮЧ вместо Flexible
                child: Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: models.isEmpty
                      ? Center(
                          child: Text(
                            'Ничего не найдено',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: models.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: scheme.outlineVariant),
                          itemBuilder: (context, i) =>
                              _buildModelTile(models[i]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Основной экран чата
