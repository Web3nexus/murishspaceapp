import 'package:flutter/material.dart';

/// Top overlay header for a live stream screen.
///
/// Layout contract: the share and close controls must always remain fully
/// visible and tappable. Everything else is flexible and degrades in priority
/// order as the available width shrinks, so the row cannot overflow:
///
///  * >= 400px — logo, LIVE pill, viewer count, wallet balance
///  * >= 340px — no logo, wallet keeps its "MSH" suffix
///  * >= 300px — viewer count dropped
///  * >= 190px — wallet balance dropped
///  * < 190px  — LIVE pill and controls only
///
/// Every element inside a pill uses a flexible, ellipsised label so a pill can
/// always shrink to a small floor instead of forcing an overflow.
class LiveStreamTopHeader extends StatelessWidget {
  const LiveStreamTopHeader({
    super.key,
    required this.viewerCount,
    required this.coinBalance,
    required this.onShare,
    required this.onClose,
    this.logoAsset = 'assets/images/murihspace-live-logo.png',
  });

  final int viewerCount;
  final num coinBalance;
  final VoidCallback onShare;
  final VoidCallback onClose;
  final String logoAsset;

  /// Width at or above which each optional element is shown.
  ///
  /// Derived from the width each element can actually shrink to, not guessed:
  /// the two controls are 48dp each and cannot shrink, the LIVE pill's floor is
  /// its padding + dot + "LIVE" text (~57dp), a pill holding an icon floors at
  /// padding + icon (~34dp), and the logo is ~75dp at its natural height.
  ///
  ///   trailing controls + gaps      = 8 + 48 + 4 + 48        = 108
  ///   + wallet pill (capped)        = 8 + 80 + 8              =  96  -> 204
  ///   + LIVE pill                    = 57                      -> 261
  ///   + viewer pill (with gap)       = 8 + 34                  -> 303
  ///   + logo (with gaps)             = 8 + 75 + 8              -> 394
  static const double logoMinWidth = 410;
  static const double viewerCountMinWidth = 340;
  static const double walletMinWidth = 285;

  /// Below this even the LIVE pill no longer fits alongside the controls, which
  /// always win. No shipping device is this narrow, but the widget must not
  /// overflow at any width.
  static const double livePillMinWidth = 200;

  /// Caps the wallet pill so a large balance cannot push the controls offscreen.
  static const double walletMaxWidth = 80;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showLogo = width >= logoMinWidth;
        final showViewerCount = width >= viewerCountMinWidth;
        final showWallet = width >= walletMinWidth;
        final showLivePill = width >= livePillMinWidth;
        final showSuffix = width >= 340;
        final showCoinIcon = width >= 240;

        return Row(
          children: [
            // Leading cluster takes all remaining space and shrinks internally.
            // The trailing controls are a single group with a bounded natural
            // width, so the two halves cannot fight over the same free space.
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLogo) ...[
                    Flexible(
                      child: Image.asset(
                        logoAsset,
                        height: 26,
                        fit: BoxFit.contain,
                        semanticLabel: 'MurihSpace LIVE',
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (showLivePill) const _LivePill(),
                  if (showViewerCount && showLivePill) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: _Pill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.remove_red_eye_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$viewerCount',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showWallet) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: walletMaxWidth,
                ),
                child: _Pill(
                  borderColor: const Color(
                    0xFFFF9500,
                  ).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showCoinIcon) ...[
                        const Text(
                          '🪙 ',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          showSuffix ? '$coinBalance MSH' : '$coinBalance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFF9500),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            _CircleControl(
              icon: Icons.share_rounded,
              tooltip: 'Share live stream',
              onPressed: onShare,
            ),
            const SizedBox(width: 4),
            _CircleControl(
              icon: Icons.close_rounded,
              tooltip: 'End or leave stream',
              onPressed: onClose,
            ),
          ],
        );
      },
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 7),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'LIVE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: child,
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
      ),
      icon: Icon(icon, color: Colors.white, size: 20),
      onPressed: onPressed,
    );
  }
}
