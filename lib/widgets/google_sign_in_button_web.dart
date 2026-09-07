import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class GoogleWebSignInButton extends StatelessWidget {
  const GoogleWebSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return web.renderButton(
      configuration: web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        shape: web.GSIButtonShape.rectangular,
      ),
    );
  }
}
