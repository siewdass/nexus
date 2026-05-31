import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? text, bool? isStreaming}) => ChatMessage(
        text: text ?? this.text,
        isUser: isUser,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

class ChatWidget extends StatefulWidget {
  final Widget header;
  final Stream<String> Function(String text)? onSend;

  const ChatWidget({super.key, required this.header, this.onSend});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final List<ChatMessage> _messages = [];
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _textCtrl.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: '', isUser: false, isStreaming: true));
      _sending = true;
    });
    _scrollDown();

    if (widget.onSend != null) {
      try {
        final stream = widget.onSend!(text);
        await for (final token in stream) {
          final idx = _messages.length - 1;
          setState(() {
            _messages[idx] = _messages[idx].copyWith(
              text: _messages[idx].text + token,
            );
          });
          _scrollDown();
        }
        setState(() {
          _messages.last = _messages.last.copyWith(isStreaming: false);
          _sending = false;
        });
      } catch (e) {
        setState(() {
          _messages.last = _messages.last.copyWith(
            text: 'Error: $e',
            isStreaming: false,
          );
          _sending = false;
        });
      }
    } else {
      setState(() {
        _messages.last = _messages.last.copyWith(isStreaming: false);
        _sending = false;
      });
    }
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Column(
      children: [
        widget.header,
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text('Envía un mensaje para empezar',
                      style: TextStyle(color: theme.secondaryText, fontSize: 12)),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _bubble(theme, msg, index);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: theme.sidebarBg,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  enabled: !_sending,
                  style: TextStyle(color: theme.primaryText, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(color: theme.secondaryText, fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.inactiveBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.primaryText,
                        ),
                      )
                    : Icon(Icons.send, color: theme.primaryText, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(ThemeService theme, ChatMessage msg, int index) {
    final align = msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = msg.isUser ? theme.green : theme.inactiveBg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: msg.isStreaming && msg.text.isEmpty
                ? SizedBox(
                    width: 20,
                    height: 12,
                    child: LinearProgressIndicator(
                      color: theme.primaryText,
                      backgroundColor: Colors.transparent,
                      minHeight: 3,
                    ),
                  )
                : SelectableText(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser ? Colors.white : theme.primaryText,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
