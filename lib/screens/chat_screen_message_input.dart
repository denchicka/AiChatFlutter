part of 'chat_screen.dart';

class _MessageInput extends StatefulWidget {
  final void Function(String) onSubmitted;

  const _MessageInput({required this.onSubmitted});

  @override
  _MessageInputState createState() => _MessageInputState();
}

// Состояние виджета ввода сообщений
class _MessageInputState extends State<_MessageInput> {
  final _controller = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    // Добавляем слушатель для отслеживания изменений текста без setState
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  /// Обработчик изменений текста без вызова setState при каждом изменении
  /// Это предотвращает дергание курсора
  void _onTextChanged() {
    final isComposing = _controller.text.trim().isNotEmpty;
    // Обновляем состояние только если оно изменилось
    if (_isComposing != isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }
  }

  void _handleSubmitted(String text) {
    final cleaned = text.trimRight();
    if (cleaned.isEmpty) return;

    // Сохраняем фокус перед очисткой, чтобы курсор не дергался
    final hadFocus = _textFocusNode.hasFocus;
    _controller.clear();
    setState(() => _isComposing = false);
    
    // Восстанавливаем фокус после очистки, если он был
    if (hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_textFocusNode.hasFocus) {
          _textFocusNode.requestFocus();
        }
      });
    }
    
    widget.onSubmitted(cleaned);
  }

  bool _isEnter(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoading = context.watch<ChatProvider>().isLoading;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              // ВАЖНО: НЕ передаём сюда _textFocusNode — иначе снова будет цикл
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;

                final isEnter = _isEnter(event.logicalKey);
                if (!isEnter) return KeyEventResult.ignored;

                final hasShift = HardwareKeyboard.instance.isShiftPressed;

                // Shift + Enter => перенос строки (даём TextField самому вставить '\n')
                if (hasShift) {
                  return KeyEventResult.ignored;
                }

                // Enter => отправка (и не вставляем перенос)
                final trimmed = _controller.text.trim();
                if (trimmed.isEmpty) return KeyEventResult.handled;

                if (!isLoading) {
                  _handleSubmitted(_controller.text);
                }
                return KeyEventResult.handled;
              },

              child: TextField(
                focusNode: _textFocusNode,
                controller: _controller,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                // Убрали onChanged - теперь используем слушатель контроллера
                // Это предотвращает дергание курсора при каждом изменении
                decoration: const InputDecoration(
                  hintText: 'Введите сообщение...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(isLoading ? Icons.stop : Icons.send, size: 20),
            tooltip: isLoading
                ? 'Остановить'
                : 'Отправить (Enter), Shift+Enter — новая строка',
            color: (_isComposing && !isLoading)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            onPressed: isLoading
                ? () => context.read<ChatProvider>().cancelCurrentRequest()
                : (_isComposing
                    ? () => _handleSubmitted(_controller.text)
                    : null),
          ),
        ],
      ),
    );
  }
}

