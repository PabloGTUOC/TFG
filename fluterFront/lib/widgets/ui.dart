import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// ── VCard (components/VCard.vue) ──────────────────────────────────
class VCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const VCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = const EdgeInsets.only(bottom: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 25, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// ── VButton (components/VButton.vue) ──────────────────────────────
enum VButtonType { primary, secondary, outline, danger }

class VButton extends StatelessWidget {
  final VButtonType type;
  final bool block;
  final bool disabled;
  final VoidCallback? onPressed;
  final Widget child;

  const VButton({
    super.key,
    this.type = VButtonType.primary,
    this.block = false,
    this.disabled = false,
    this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side, shadow) = switch (type) {
      VButtonType.primary => (
          AppColors.primary,
          Colors.white,
          BorderSide.none,
          const [
            BoxShadow(
                color: Color(0x4D2563EB), blurRadius: 14, offset: Offset(0, 4))
          ],
        ),
      VButtonType.secondary => (
          const Color(0x0D0F172A),
          AppColors.textPrimary,
          const BorderSide(color: AppColors.inputBorder),
          const <BoxShadow>[],
        ),
      VButtonType.outline => (
          Colors.transparent,
          AppColors.primary,
          const BorderSide(color: AppColors.primary),
          const <BoxShadow>[],
        ),
      VButtonType.danger => (
          AppColors.dangerSoft,
          AppColors.danger,
          const BorderSide(color: AppColors.dangerSoft),
          const <BoxShadow>[],
        ),
    };

    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: disabled ? const [] : shadow,
      ),
      child: FilledButton(
        onPressed: disabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          disabledForegroundColor: fg.withValues(alpha: 0.6),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            side: side,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        child: child,
      ),
    );

    return block ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// ── VInput (components/VInput.vue) ────────────────────────────────
class VInput extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final bool obscure;
  final bool enabled;
  final bool pill;
  final int maxLines;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const VInput({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.obscure = false,
    this.enabled = true,
    this.pill = true,
    this.maxLines = 1,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
        pill && maxLines == 1 ? AppRadii.pill : AppRadii.md);
    return Column(
      // min, or a VInput used directly as AlertDialog content stretches
      // the dialog to full screen height.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!,
              style: const TextStyle(
                  fontSize: 13.6,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0x8094A3B8)),
            filled: true,
            fillColor: AppColors.inputBg,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: AppColors.inputBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            disabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: AppColors.inputBorder)),
          ),
        ),
      ],
    );
  }
}

/// ── KpiCard (components/KpiCard.vue) ──────────────────────────────
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? subtitle;
  final String? delta;
  final Color accent;
  final Color deltaColor;
  final Color deltaBg;
  final double? progress; // 0–100

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.subtitle,
    this.delta,
    this.accent = AppColors.primary,
    this.deltaColor = AppColors.success,
    this.deltaBg = AppColors.successSoft,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final compact = !isWideLayout(context);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius:
            BorderRadius.circular(compact ? AppRadii.md : AppRadii.lg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0E1726), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    style: TextStyle(
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary)),
              ),
              if (delta != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: deltaBg,
                      borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Text(delta!,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: deltaColor)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: compact ? 20 : 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1,
                      color: accent)),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Text(unit!,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: TextStyle(
                    fontSize: compact ? 10 : 12,
                    color: AppColors.textSecondary)),
          ],
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: (progress!.clamp(0, 100)) / 100,
                minHeight: compact ? 2 : 3,
                backgroundColor: AppColors.bg,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ── Avatar circle with initial ─────────────────────────────────────
class AvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  final Color? background;
  final Color? foreground;

  /// Backend-relative (`/uploads/...`) or absolute avatar image URL.
  /// Falls back to the initial when null or when loading fails.
  final String? imageUrl;

  const AvatarCircle({
    super.key,
    required this.name,
    this.size = 40,
    this.background,
    this.foreground,
    this.imageUrl,
  });

  /// Resolves relative avatar paths against the API origin (avatarStyle.js).
  static String? resolve(dynamic url) {
    final s = url?.toString() ?? '';
    if (s.isEmpty) return null;
    return s.startsWith('http') ? s : '${ApiClient.apiBase}$s';
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final resolved = resolve(imageUrl);
    final fallback = Text(initial,
        style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: foreground ?? Colors.white));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        gradient: background == null ? AppColors.accentGradient : null,
        shape: BoxShape.circle,
      ),
      child: resolved == null
          ? fallback
          : Image.network(resolved,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Decode at display resolution so the image cache holds small
              // bitmaps, and keep the old frame while a URL re-resolves.
              cacheWidth:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback),
    );
  }
}

/// ── Small pill badge (badge / coin-badge styles) ───────────────────
class PillBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final double fontSize;

  const PillBadge({
    super.key,
    required this.text,
    this.color = AppColors.warning,
    this.background = AppColors.warningSoft,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(text,
          style: TextStyle(
              fontSize: fontSize, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// ── Segmented tab bar (marketplace .mkt-tab-bar / activity filters) ─
class SegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedTabs(
      {super.key,
      required this.tabs,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // scaleDown keeps all three labels visible on 320dp-wide phones instead
    // of overflowing ("Catalogue / New Activity / Budget").
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < tabs.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color:
                        i == selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(tabs[i],
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: i == selected
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Error placeholder with a retry button. Shown when a screen's load fails
/// and there is no data to fall back on, so failures stop masquerading as
/// empty states on flaky connections.
class LoadErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const LoadErrorState({
    super.key,
    required this.onRetry,
    this.message = 'Couldn\'t load data.\nCheck your connection and try again.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.5)),
            const SizedBox(height: 18),
            VButton(
                type: VButtonType.outline,
                onPressed: onRetry,
                child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Page heading matching the Vue views' large titles.
class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PageHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final mobile = !isWideLayout(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: mobile ? 28 : 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: AppColors.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary, height: 1.6)),
        ],
        const SizedBox(height: 28),
      ],
    );
  }
}
