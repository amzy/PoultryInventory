import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentPage(
      title: 'Privacy Policy',
      sections: _privacySections,
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentPage(
      title: 'Terms & Conditions',
      sections: _termsSections,
    );
  }
}

class _LegalSection {
  final String title;
  final String body;
  const _LegalSection(this.title, this.body);
}

class _LegalDocumentPage extends StatelessWidget {
  final String title;
  final List<_LegalSection> sections;

  const _LegalDocumentPage({
    required this.title,
    required this.sections,
  });

  static const _green = Color(0xFF087A4F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Poultry Inventory',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _green,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$title\nLast updated: September 12, 2026',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 24),
                    ...sections.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              section.body,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.65,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 14),
                    Text(
                      'Contact: amzy21@gmail.com',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _privacySections = <_LegalSection>[
  _LegalSection(
    '1. Information We May Collect',
    'Depending on the features you use, Poultry Inventory may process account information needed for authentication, poultry inventory and operational information that you enter, images or files you choose to upload or share, and limited technical information needed to operate, secure, troubleshoot, and improve the application.\n\nWe do not intend to collect sensitive personal information unless a feature specifically requires it and you voluntarily provide it.',
  ),
  _LegalSection(
    '2. How We Use Information',
    'We may use information to provide and operate the application, authenticate users and protect accounts, store and synchronize inventory information, provide support and troubleshoot technical problems, maintain security, prevent abuse, and improve reliability.',
  ),
  _LegalSection(
    '3. Firebase and Third-Party Services',
    'Poultry Inventory uses Firebase services where enabled by the application, including services that may provide authentication, database, cloud storage, or related backend functionality. Firebase may process information on our behalf according to our project configuration and applicable Firebase policies.\n\nThe application may also use platform or third-party services required by particular features. Those services handle information according to their applicable terms and privacy policies.',
  ),
  _LegalSection(
    '4. Data Storage and Security',
    'We use reasonable technical and organizational measures intended to protect information against unauthorized access, alteration, disclosure, or destruction. No internet transmission or electronic storage system can be guaranteed to be completely secure.',
  ),
  _LegalSection(
    '5. Data Retention',
    'Information is retained for as long as reasonably necessary to provide the application, maintain legitimate business records, comply with legal obligations, resolve disputes, and enforce agreements. Retention periods may vary depending on the type of information and its purpose.',
  ),
  _LegalSection(
    '6. Sharing of Information',
    'We do not sell your personal information. Information may be disclosed to service providers that help us operate the application, when required by law, to protect rights or safety, or as part of a legitimate business transaction such as a merger or transfer of assets.',
  ),
  _LegalSection(
    '7. Your Choices and Data Requests',
    'You may request access to, correction of, or deletion of personal information associated with your account, subject to applicable law and legitimate retention requirements. Contact us using the support address shown below.',
  ),
  _LegalSection(
    '8. Children’s Privacy',
    'The application is intended for general business use and is not directed specifically to children. We do not knowingly collect personal information from children in violation of applicable law.',
  ),
  _LegalSection(
    '9. Changes to This Privacy Policy',
    'We may update this Privacy Policy when the application, our data practices, or legal requirements change. The updated version will be posted in the application with a revised last-updated date.',
  ),
];

const _termsSections = <_LegalSection>[
  _LegalSection(
    '1. Acceptance and Use',
    'These Terms & Conditions govern your use of Poultry Inventory. By using the application, you agree to these Terms. You may use the application only for lawful purposes and in accordance with these Terms.',
  ),
  _LegalSection(
    '2. Accounts',
    'If the application requires an account, you agree to provide accurate information and keep your authentication details secure. You are responsible for activity performed through your account except where caused by circumstances outside your reasonable control.',
  ),
  _LegalSection(
    '3. Inventory Data',
    'The application helps organize poultry inventory and related operational information. You remain responsible for verifying records, quantities, calculations, and business decisions. Poultry Inventory does not replace your own operational controls or accounting records.',
  ),
  _LegalSection(
    '4. Acceptable Use',
    'You must not use the application for unlawful, fraudulent, or abusive activities; attempt unauthorized access to the application, backend services, or another user’s account; interfere with the operation or security of the application; upload content you do not have the right to use or that violates applicable law; or reverse engineer or misuse the application except where such restriction is prohibited by applicable law.',
  ),
  _LegalSection(
    '5. Third-Party Services',
    'The application may rely on Firebase and other third-party or platform services. Their availability and use may be governed by their own terms and policies.',
  ),
  _LegalSection(
    '6. Availability and Changes',
    'We may modify, suspend, or discontinue parts of the application when reasonably necessary for maintenance, security, legal compliance, or changes to third-party services. We do not guarantee uninterrupted or error-free availability.',
  ),
  _LegalSection(
    '7. Intellectual Property',
    'Unless otherwise stated, the application and its original software, branding, design, and content are owned by or licensed to the application operator. These Terms do not transfer ownership to you.',
  ),
  _LegalSection(
    '8. Disclaimer',
    'To the extent permitted by law, the application is provided on an “as available” basis. We do not guarantee that the application will satisfy every operational requirement or that information will always be complete or accurate.',
  ),
  _LegalSection(
    '9. Limitation of Liability',
    'To the maximum extent permitted by applicable law, the application operator will not be liable for indirect, incidental, special, consequential, or business losses arising from use of or inability to use the application. Nothing in these Terms excludes liability that cannot legally be excluded.',
  ),
  _LegalSection(
    '10. Termination',
    'We may suspend or terminate access where reasonably necessary for security, legal compliance, misuse, or violation of these Terms. You may stop using the application at any time.',
  ),
  _LegalSection(
    '11. Changes to These Terms',
    'We may update these Terms from time to time. Continued use of the application after updated Terms are posted constitutes acceptance of the revised Terms to the extent permitted by law.',
  ),
];
