import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/checks_api.dart';

class CheckChatScreen extends StatefulWidget {
  const CheckChatScreen({super.key, required this.checkId, required this.title});

  final int checkId;
  final String title;

  @override
  State<CheckChatScreen> createState() => _CheckChatScreenState();
}

class _CheckChatScreenState extends State<CheckChatScreen> {
  final _api = ChecksApi();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _streaming = false;
  String? _error;

  static const _chips = <String>[
    'Стало суше',
    'Больше блеска',
    'Спокойнее',
    'Раздражение',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    // Poll so two tabs/devices with the same login stay roughly in sync.
    _pollTimer = Stream.periodic(const Duration(seconds: 4)).listen((_) {
      _pollRemote();
    });
  }

  StreamSubscription<dynamic>? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await _api.listMessages(widget.checkId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
      });
      _jumpBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить чат';
      });
    }
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  /// Smooth reveal like typical AI chats (works for LLM and rule-based replies).
  Future<void> _typewriter(ChatMessage full) async {
    final text = full.text;
    if (text.isEmpty) {
      setState(() {
        _messages.add(full);
        _streaming = false;
        _sending = false;
      });
      _jumpBottom();
      return;
    }
    setState(() {
      _streaming = true;
      _messages.add(ChatMessage(id: full.id, role: 'assistant', text: ''));
    });
    _jumpBottom();

    // Pace: ~2–3 chars per tick; keep total under ~2.5s for long replies.
    final step = text.length > 400 ? 6 : (text.length > 160 ? 3 : 2);
    final delay = Duration(milliseconds: text.length > 400 ? 12 : 16);
    for (var i = step; i < text.length; i += step) {
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] =
            ChatMessage(id: full.id, role: 'assistant', text: text.substring(0, i));
      });
      _jumpBottom();
      await Future<void>.delayed(delay);
    }
    if (!mounted) return;
    setState(() {
      _messages[_messages.length - 1] = full;
      _streaming = false;
      _sending = false;
    });
    _jumpBottom();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending || _streaming) return;
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(ChatMessage(id: -1, role: 'user', text: trimmed));
    });
    _controller.clear();
    _jumpBottom();
    try {
      final assistant = await _api.sendMessage(widget.checkId, trimmed);
      if (!mounted) return;
      await _typewriter(assistant);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _streaming = false;
        _error = 'Не удалось отправить сообщение';
      });
    }
  }

  /// Soft sync: other device / tab with same account can see new messages.
  Future<void> _pollRemote() async {
    if (_sending || _streaming || _loading) return;
    try {
      final msgs = await _api.listMessages(widget.checkId);
      if (!mounted || _sending || _streaming) return;
      if (msgs.length == _messages.length &&
          (msgs.isEmpty ||
              (_messages.isNotEmpty &&
                  msgs.last.id == _messages.last.id &&
                  msgs.last.text == _messages.last.text))) {
        return;
      }
      // Don't clobber in-progress typewriter; only refresh when idle.
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
      });
      _jumpBottom();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _streaming;
    return Scaffold(
      backgroundColor: GlowColors.mist,
      appBar: AppBar(
        title: Text('Чат · ${widget.title}'),
        backgroundColor: GlowColors.mist,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Не медуслуга. Обсуждаем адаптацию плана к ощущениям кожи в поездке.',
              style: TextStyle(color: GlowColors.muted, fontSize: 12, height: 1.35),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: GlowColors.coral)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    itemCount: _messages.length + (_sending && !_streaming ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 8, left: 4),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final m = _messages[i];
                      final mine = m.role == 'user';
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? GlowColors.sea : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: mine ? null : Border.all(color: GlowColors.line),
                          ),
                          child: Text(
                            m.text.isEmpty && !mine ? '…' : m.text,
                            style: TextStyle(
                              color: mine ? Colors.white : GlowColors.ink,
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final chip in _chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(chip),
                      onPressed: busy ? null : () => _send(chip),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Как кожа сейчас?',
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                      ),
                      enabled: !busy,
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: busy ? null : () => _send(_controller.text),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
