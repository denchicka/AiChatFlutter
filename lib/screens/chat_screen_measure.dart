part of 'chat_screen.dart';

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSize extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasureSize).onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this._onChange);

  OnWidgetSizeChange _onChange;
  set onChange(OnWidgetSizeChange v) => _onChange = v;

  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();

    final newSize = child?.size;
    if (newSize == null) return;

    if (_oldSize == newSize) return;
    _oldSize = newSize;

    WidgetsBinding.instance.addPostFrameCallback((_) => _onChange(newSize));
  }
}

class ExpandableMessageBody extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double collapsedMaxHeight;

  const ExpandableMessageBody({
    super.key,
    required this.child,
    required this.enabled,
    this.collapsedMaxHeight = 260,
  });

  @override
  State<ExpandableMessageBody> createState() => _ExpandableMessageBodyState();
}

class _ExpandableMessageBodyState extends State<ExpandableMessageBody>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _needsClamp = false;

  @override
  void initState() {
    super.initState();
    // КЛЮЧ: если включено — стартуем как будто clamp нужен,
    // чтобы не было "сначала большое, потом схлопнулось" (скачок скролла).
    _needsClamp = widget.enabled;
  }

  @override
  void didUpdateWidget(covariant ExpandableMessageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _expanded = false;
      _needsClamp = widget.enabled;
    }
  }

  void _onSize(Size size) {
    final need = size.height > widget.collapsedMaxHeight + 1;
    if (!mounted) return;

    // ВАЖНО: разрешаем только переход "clamp -> no clamp".
    // Обратный переход (no clamp -> clamp) снова даст скачок.
    if (_needsClamp && !need) {
      setState(() => _needsClamp = false);
    }
  }

  Widget _toggleChip(ColorScheme scheme) {
    final label = _expanded ? 'Свернуть' : 'Показать полностью';
    final icon =
        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.80),
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final scheme = Theme.of(context).colorScheme;

    // Важно: измеряем реальную высоту контента
    final measuredChild = MeasureSize(
      onChange: _onSize,
      child: widget.child,
    );

    // Ключевое отличие: в collapsed режиме НЕ зажимаем layout ребёнка по высоте,
    // а делаем “окно” + ClipRect + OverflowBox.
    final Widget body = (!_needsClamp || _expanded)
        ? measuredChild
        : SizedBox(
            height: widget.collapsedMaxHeight,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minHeight: 0,
                maxHeight: double.infinity,
                child: measuredChild,
              ),
            ),
          );

    final withFade = Stack(
      children: [
        body,
        if (!_expanded && _needsClamp)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.surface.withValues(alpha: 0.0),
                      scheme.surface.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: withFade,
        ),
        if (_needsClamp) const SizedBox(height: 6),
        if (_needsClamp) _toggleChip(scheme),
      ],
    );
  }
}

