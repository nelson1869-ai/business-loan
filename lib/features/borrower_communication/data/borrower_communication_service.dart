import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/phone_number.dart';

/// Platform boundary for opening an editable SMS draft and Android sharing.
class BorrowerCommunicationService {
  const BorrowerCommunicationService({
    this.canLaunch = canLaunchUrl,
    this.launch = launchUrl,
  });

  final Future<bool> Function(Uri uri) canLaunch;
  final Future<bool> Function(Uri uri, {LaunchMode mode}) launch;

  /// Opens the installed SMS application. It never sends the message.
  Future<bool> openSmsDraft(PhilippinePhoneNumber phone, String message) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone.e164,
      queryParameters: <String, String>{'body': message},
    );
    if (!await canLaunch(uri)) return false;
    return launch(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens the operating-system share sheet.
  Future<void> shareText(String message) async {
    await SharePlus.instance.share(ShareParams(text: message));
  }

  /// Shares one generated PDF through the operating-system share sheet.
  Future<void> sharePdf(String path, String title) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: title,
        text: '$title — Lending Nelson',
        files: <XFile>[XFile(path, mimeType: 'application/pdf')],
      ),
    );
  }
}

final borrowerCommunicationServiceProvider =
    Provider<BorrowerCommunicationService>((ref) {
      return const BorrowerCommunicationService();
    });
