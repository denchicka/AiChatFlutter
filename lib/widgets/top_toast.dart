import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'top_toast_theme.dart';
import 'top_toast_types.dart';

// Удобно: чтобы другие файлы импортировали только top_toast.dart
export 'top_toast_types.dart';

class TopToast {
  static OverlayEntry? _entry;
  static final GlobalKey<_TopToastHostState> _hostKey =
      GlobalKey<_TopToastHostState>();
  static final List<_PendingToast> _pending = [];
  static bool _flushScheduled = false;

  static String? _lastMsg;
  static DateTime? _lastShownAt;

  static bool get isShown => _entry != null;

  static Future<void> dismissAll() async {
    _pending.clear();
    _flushScheduled = false;

    final host = _hostKey.currentState;
    if (host != null) {
      await host.clearAll();
    }
    _removeOverlay();
  }

  static void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;

    // Просим фрейм, чтобы postFrame точно случился
    WidgetsBinding.instance.ensureVisualUpdate();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;

      final host = _hostKey.currentState;
      if (host == null) {
        // Host ещё не смонтирован — повторим попытку, если есть что показывать
        if (_pending.isNotEmpty) _scheduleFlush();
        return;
      }

      for (final p in _pending) {
        host.push(p.data, maxStack: p.maxStack);
      }
      _pending.clear();
    });
  }

  static void show(
    BuildContext context,
    String message, {
    TopToastType type = TopToastType.info,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
    int maxStack = 3,
  }) {
    // Дедупликация: часто один и тот же toast может прилетать несколько раз подряд
    // из-за rebuild/notifyListeners (особенно при старте/переключениях).
    final now = DateTime.now();
    if (_lastMsg == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!).inMilliseconds < 600) {
      return;
    }
    _lastMsg = message;
    _lastShownAt = now;

    final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
        Navigator.maybeOf(context)?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.maybeOf(context);

    if (overlay == null) {
      debugPrint('TopToast: No Overlay found for context=$context');
      return;
    }

    _ensureOverlay(overlay);

    final data = _ToastData(
      id: UniqueKey().toString(),
      message: message,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    final host = _hostKey.currentState;
    if (host != null) {
      host.push(data, maxStack: maxStack);
    } else {
      // Host ещё не смонтирован (OverlayEntry вставили только что)
      _pending.add(_PendingToast(data, maxStack));
      _scheduleFlush();
    }
  }

  static void _ensureOverlay(OverlayState overlay) {
    if (_entry != null) return;

    _entry = OverlayEntry(
      builder: (ctx) => _TopToastHost(key: _hostKey),
    );

    overlay.insert(_entry!);
  }

  static void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  static void _removeOverlayIfEmpty() {
    final host = _hostKey.currentState;
    if (host == null) return;

    // ВАЖНО: если есть pending или запланирован flush — overlay не трогаем
    if (_pending.isNotEmpty || _flushScheduled) return;

    if (!host.hasToasts) _removeOverlay();
  }
}

class _ToastData {
  final String id;
  final String message;
  final TopToastType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  _ToastData({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
    required this.actionLabel,
    required this.onAction,
  });
}

class _PendingToast {
  final _ToastData data;
  final int maxStack;
  _PendingToast(this.data, this.maxStack);
}

class _TopToastHost extends StatefulWidget {
  const _TopToastHost({super.key});

  @override
  State<_TopToastHost> createState() => _TopToastHostState();
}

class _TopToastHostState extends State<_TopToastHost> {
  final List<_ToastData> _items = [];

  bool get hasToasts => _items.isNotEmpty;

  void push(_ToastData data, {required int maxStack}) {
    setState(() {
      _items.insert(0, data);
      if (_items.length > maxStack) {
        _items.removeRange(maxStack, _items.length);
      }
    });
  }

  Future<void> dismiss(String id) async {
    if (!mounted) return;

    setState(() {
      _items.removeWhere((e) => e.id == id);
    });

    if (_items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TopToast._removeOverlayIfEmpty();
      });
    }
  }

  Future<void> clearAll() async {
    if (!mounted) return;
    setState(() => _items.clear());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TopToast._removeOverlayIfEmpty();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).extension<TopToastTheme>() ??
        TopToastTheme.fromScheme(scheme);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in _items) ...[
                  _TopToastCard(
                    key: ValueKey(t.id),
                    data: t,
                    theme: tt,
                    onDismiss: () => dismiss(t.id),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopToastCard extends StatefulWidget {
  final _ToastData data;
  final TopToastTheme theme;
  final VoidCallback onDismiss;

  const _TopToastCard({
    super.key,
    required this.data,
    required this.theme,
    required this.onDismiss,
  });

  @override
  State<_TopToastCard> createState() => _TopToastCardState();
}

class _TopToastCardState extends State<_TopToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _hiding = false;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: widget.theme.animationIn,
      reverseDuration: widget.theme.animationOut,
    );

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

    _c.forward();

    _timer = Timer(widget.data.duration, () {
      if (!mounted) return;
      hide();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> hide() async {
    if (_hiding) return;
    _hiding = true;

    _timer?.cancel();
    await _c.reverse();

    if (!mounted) return;
    widget.onDismiss();
  }

  IconData get _icon => switch (widget.data.type) {
        TopToastType.info => Icons.info_outline,
        TopToastType.success => Icons.check_circle_outline,
        TopToastType.error => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.theme.resolve(widget.data.type);

    final hasAction =
        widget.data.actionLabel != null && widget.data.onAction != null;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Dismissible(
          key: ValueKey('toast_${widget.data.id}'),
          direction: DismissDirection.up,
          onDismissed: (_) => hide(),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasAction
                  ? () async {
                      widget.data.onAction?.call();
                      await hide();
                    }
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.theme.radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: widget.theme.padding,
                    decoration: BoxDecoration(
                      color: r.bg.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(widget.theme.radius),
                      border: Border.all(color: r.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(_icon, size: 18, color: r.fg),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.data.message,
                                style: TextStyle(
                                  color: r.fg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600, // было w650
                                ),
                              ),
                            ),
                            if (hasAction) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  widget.data.onAction?.call();
                                  await hide();
                                },
                                child: Text(
                                  widget.data.actionLabel!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: hide,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.data.duration >=
                            const Duration(milliseconds: 1800)) ...[
                          const SizedBox(height: 8),
                          _ToastProgressLine(
                            duration: widget.data.duration,
                            color: r.fg.withValues(alpha: 0.45),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastProgressLine extends StatelessWidget {
  final Duration duration;
  final Color color;

  const _ToastProgressLine({
    required this.duration,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: duration,
      curve: Curves.linear,
      builder: (context, v, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 2.5,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v,
                child: Container(color: color),
              ),
            ),
          ),
        );
      },
    );
  }
}
