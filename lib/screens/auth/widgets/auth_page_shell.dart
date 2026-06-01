import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';

class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.header,
    required this.cardChild,
    required this.footer,
    this.maxCardWidth = 620,
  });

  final Widget header;
  final Widget cardChild;
  final Widget footer;
  final double maxCardWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 640
                    ? 20.0
                    : 32.0;
                const verticalPadding = 24.0;
                final footerInset = constraints.maxWidth < 640 ? 96.0 : 116.0;

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        verticalPadding,
                        horizontalPadding,
                        verticalPadding + footerInset,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight -
                              (verticalPadding * 2) -
                              footerInset,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxCardWidth + 80,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                header,
                                const SizedBox(height: 28),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxCardWidth,
                                  ),
                                  child: AuthCard(child: cardChild),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: verticalPadding,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxCardWidth + 140,
                          ),
                          child: footer,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final padding = screenWidth < 640
        ? const EdgeInsets.all(24)
        : const EdgeInsets.symmetric(horizontal: 40, vertical: 36);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF061326).withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: compact ? 22 : 30,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF08152B),
        letterSpacing: -0.8,
      ),
    );

    final subtitleWidget = subtitle == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: compact ? 8 : 10),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 15 : 16,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          );

    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandMark(size: 42),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF08152B),
                    letterSpacing: -0.6,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const BrandMark(),
        const SizedBox(height: 22),
        titleWidget,
        subtitleWidget,
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 60});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF071A34),
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF071A34).withValues(alpha: 0.18),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        size: size * 0.52,
        color: Colors.white,
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF18263C),
              letterSpacing: 1.6,
            ),
          ),
        ),
        if (trailing != null) trailing! else const SizedBox.shrink(),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixPressed,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF14233B),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF6F7B8B)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF434C58), size: 22),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: onSuffixPressed,
                icon: Icon(
                  suffixIcon,
                  color: const Color(0xFF434C58),
                  size: 22,
                ),
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFFD9E1EA).withValues(alpha: 0.85),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0D2951), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
    );
  }
}

class AuthNoticeBanner extends StatelessWidget {
  const AuthNoticeBanner({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF27466D)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1D3252)),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF071A34),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(
            0xFF071A34,
          ).withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded, size: 24),
                ],
              ),
      ),
    );
  }
}

class AuthSecurityPill extends StatelessWidget {
  const AuthSecurityPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE8FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF123B89)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF123B89),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthFooterLinks extends StatelessWidget {
  const AuthFooterLinks({
    super.key,
    required this.links,
    this.copyright,
    this.showDivider = false,
  });

  final List<String> links;
  final String? copyright;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 640;

    return Column(
      children: [
        if (showDivider)
          Container(
            width: double.infinity,
            height: 1,
            margin: const EdgeInsets.only(bottom: 18),
            color: const Color(0xFFD5DDE8),
          ),
        if (copyright != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              copyright!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C8796)),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: isCompact ? 18 : 28,
          runSpacing: 10,
          children: [
            for (final link in links)
              Text(
                link,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF55657C),
                  letterSpacing: 0.6,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFDFEFF), Color(0xFFF4F7FC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: -130,
            left: -150,
            child: _GlowOrb(
              size: 360,
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                const Color(0xFFCFE0FF).withValues(alpha: 0.35),
              ],
            ),
          ),
          Positioned(
            top: -60,
            right: -110,
            child: _GlowOrb(
              size: 420,
              colors: [
                const Color(0xFFD9E7FF).withValues(alpha: 0.85),
                const Color(0xFFECF3FF).withValues(alpha: 0.15),
              ],
            ),
          ),
          Positioned(
            bottom: -140,
            left: -80,
            child: _GlowOrb(
              size: 320,
              colors: [
                const Color(0xFFDCE7FA).withValues(alpha: 0.8),
                const Color(0xFFF7FAFF).withValues(alpha: 0.08),
              ],
            ),
          ),
          Positioned(
            bottom: 80,
            right: 36,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    const Color(0xFFE5EEFA).withValues(alpha: 0.22),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
              ),
              child: Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9BD9FF).withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFFEAF4FF),
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 90,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}
