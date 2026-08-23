import 'package:flutter/material.dart';
import 'package:jovial_svg/jovial_svg.dart';

import '../providers/app_icon_provider.dart';

/// 启动页 Logo 动画。
///
/// 启动页和关于页使用同一套 ForumFlow SVG 母版，避免启动动画继续显示
/// 已经废弃的旧品牌几何图形。动画只负责入场、缩放和光晕，Logo 本身由
/// 可复用的矢量资源渲染，因此小尺寸和高 DPI 屏幕都保持清晰。
class PreheatLogo extends StatefulWidget {
  final AppIconStyle style;
  final double size;

  const PreheatLogo({super.key, required this.style, this.size = 108});

  @override
  State<PreheatLogo> createState() => _PreheatLogoState();
}

class _PreheatLogoState extends State<PreheatLogo>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );
  late final AnimationController _glow = AnimationController(
    duration: const Duration(milliseconds: 2400),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _entry
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _glow.repeat(reverse: true);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    _glow.dispose();
    super.dispose();
  }

  String _assetPath(BuildContext context) {
    if (widget.style != AppIconStyle.modern) {
      return 'assets/logo.svg';
    }
    return Theme.of(context).brightness == Brightness.light
        ? 'assets/logo_modern_light.svg'
        : 'assets/logo_modern.svg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetPath = _assetPath(context);
    final logo = SizedBox(
      width: widget.size,
      height: widget.size,
      child: ScalableImageWidget.fromSISource(
        si: ScalableImageSource.fromSvg(
          DefaultAssetBundle.of(context),
          assetPath,
          warnF: (_) {},
        ),
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_entry, _glow]),
      child: logo,
      builder: (context, child) {
        final entry = Curves.easeOutBack.transform(_entry.value);
        final breathe = Curves.easeInOutSine.transform(_glow.value);
        final glowAlpha = 0.10 + (0.08 * breathe);
        final glowBlur = 28.0 + (16.0 * breathe);

        return Opacity(
          opacity: Curves.easeOut.transform(_entry.value),
          child: Transform.scale(
            scale: 0.86 + (0.14 * entry),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(
                      alpha: glowAlpha,
                    ),
                    blurRadius: glowBlur,
                  ),
                ],
              ),
              child: RepaintBoundary(child: child!),
            ),
          ),
        );
      },
    );
  }
}
