import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MessagePreviewAction { sms, share }

class MessagePreviewResult {
  const MessagePreviewResult(this.action, this.message);
  final MessagePreviewAction action;
  final String message;
}

/// Editable confirmation boundary shown before any external application opens.
class MessagePreviewDialog extends StatefulWidget {
  const MessagePreviewDialog({
    super.key,
    required this.initialMessage,
    this.smsEnabled = true,
  });

  final String initialMessage;
  final bool smsEnabled;

  static Future<MessagePreviewResult?> show(
    BuildContext context,
    String message, {
    bool smsEnabled = true,
  }) => showDialog<MessagePreviewResult>(
    context: context,
    builder: (_) =>
        MessagePreviewDialog(initialMessage: message, smsEnabled: smsEnabled),
  );

  @override
  State<MessagePreviewDialog> createState() => _MessagePreviewDialogState();
}

class _MessagePreviewDialogState extends State<MessagePreviewDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialMessage,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review message'),
      content: SizedBox(
        width: 520,
        child: TextField(
          key: const Key('borrower-message-editor'),
          controller: _controller,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(
            labelText: 'Message',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          key: const Key('copy-edited-message'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _controller.text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Message copied.')));
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy'),
        ),
        OutlinedButton.icon(
          onPressed: widget.smsEnabled
              ? () => Navigator.pop(
                  context,
                  MessagePreviewResult(
                    MessagePreviewAction.sms,
                    _controller.text.trim(),
                  ),
                )
              : null,
          icon: const Icon(Icons.sms_outlined),
          label: const Text('Continue to SMS'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            MessagePreviewResult(
              MessagePreviewAction.share,
              _controller.text.trim(),
            ),
          ),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share'),
        ),
      ],
    );
  }
}
