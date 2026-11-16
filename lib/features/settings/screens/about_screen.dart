/// Acerca de / contacto: breve descripción y correo para reportar fallos.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pandive/l10n/app_localizations.dart';

const _email = 'pandive@drslump.org';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _contact(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).emailCopied;
    final uri = Uri(
        scheme: 'mailto', path: _email, queryParameters: {'subject': 'Pandive'});
    final ok = await launchUrl(uri);
    if (!ok) {
      await Clipboard.setData(const ClipboardData(text: _email));
      messenger.showSnackBar(SnackBar(content: Text(copied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.about)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/logo/pandive_splash.png',
                  width: 96, height: 96),
            ),
            const SizedBox(height: 12),
            Text('Pandive', style: tt.headlineSmall),
            const SizedBox(height: 16),
            Text(t.aboutIntro, textAlign: TextAlign.center, style: tt.bodyMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.email_outlined),
              label: Text(t.contactEmail),
              onPressed: () => _contact(context),
            ),
            const SizedBox(height: 8),
            SelectableText(_email, style: tt.bodySmall),
          ],
        ),
      ),
    );
  }
}
