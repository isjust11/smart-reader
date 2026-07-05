import 'package:flutter/material.dart';

/// Chia không gian thành nhiều khung theo tỷ lệ [flexes] (ví dụ `[2, 1]` →
/// khung A ~66%, khung B ~33%). Khi kéo giãn màn hình, tỷ lệ được giữ; có thể
/// kéo thanh chia (splitter) để đổi tỷ lệ thủ công.
class ProportionalSplitView extends StatefulWidget {
  final Axis direction;
  final List<Widget> children;
  final List<double> flexes;
  final double dividerThickness;
  final List<double>? minSizes;

  const ProportionalSplitView({
    super.key,
    required this.direction,
    required this.children,
    required this.flexes,
    this.dividerThickness = 6,
    this.minSizes,
  }) : assert(children.length >= 2),
       assert(flexes.length == children.length);

  @override
  State<ProportionalSplitView> createState() => _ProportionalSplitViewState();
}

class _ProportionalSplitViewState extends State<ProportionalSplitView> {
  late List<double> _weights;

  @override
  void initState() {
    super.initState();
    _weights = _normalize(widget.flexes);
  }

  @override
  void didUpdateWidget(covariant ProportionalSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flexes != widget.flexes ||
        oldWidget.children.length != widget.children.length) {
      _weights = _normalize(widget.flexes);
    }
  }

  List<double> _normalize(List<double> flexes) {
    final sum = flexes.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) {
      final even = 1 / flexes.length;
      return List.filled(flexes.length, even);
    }
    return flexes.map((f) => f / sum).toList();
  }

  double _minSizeFor(int index) => widget.minSizes?[index] ?? 80;

  void _onDividerDrag(int dividerIndex, double delta, double available) {
    if (available <= 0) return;

    final i = dividerIndex;
    final j = dividerIndex + 1;
    final pairTotal = _weights[i] + _weights[j];
    final deltaWeight = delta / available;

    var nextI = (_weights[i] + deltaWeight).clamp(0.0, pairTotal);
    var nextJ = pairTotal - nextI;

    final minI = _minSizeFor(i) / available;
    final minJ = _minSizeFor(j) / available;
    if (nextI < minI) {
      nextI = minI;
      nextJ = pairTotal - nextI;
    }
    if (nextJ < minJ) {
      nextJ = minJ;
      nextI = pairTotal - nextJ;
    }

    setState(() {
      _weights[i] = nextI;
      _weights[j] = nextJ;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.direction == Axis.horizontal;
    final dividerCount = widget.children.length - 1;
    final dividerTotal = widget.dividerThickness * dividerCount;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final available = (total - dividerTotal).clamp(0.0, double.infinity);

        final sizes = List<double>.generate(
          widget.children.length,
          (i) => _weights[i] * available,
        );

        final children = <Widget>[];
        for (var i = 0; i < widget.children.length; i++) {
          children.add(
            SizedBox(
              width: isHorizontal ? sizes[i] : constraints.maxWidth,
              height: isHorizontal ? constraints.maxHeight : sizes[i],
              child: widget.children[i],
            ),
          );
          if (i < dividerCount) {
            children.add(
              _SplitDivider(
                direction: widget.direction,
                thickness: widget.dividerThickness,
                colorScheme: colorScheme,
                onDrag: (delta) => _onDividerDrag(i, delta, available),
              ),
            );
          }
        }

        return isHorizontal
            ? Row(children: children)
            : Column(children: children);
      },
    );
  }
}

class _SplitDivider extends StatefulWidget {
  final Axis direction;
  final double thickness;
  final ColorScheme colorScheme;
  final ValueChanged<double> onDrag;

  const _SplitDivider({
    required this.direction,
    required this.thickness,
    required this.colorScheme,
    required this.onDrag,
  });

  @override
  State<_SplitDivider> createState() => _SplitDividerState();
}

class _SplitDividerState extends State<_SplitDivider> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.direction == Axis.horizontal;
    final active = _hovering || _dragging;
    final lineColor = active
        ? widget.colorScheme.primary
        : widget.colorScheme.outline.withValues(alpha: 0.35);

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: isHorizontal
            ? (_) => setState(() => _dragging = true)
            : null,
        onHorizontalDragUpdate: isHorizontal
            ? (d) => widget.onDrag(d.delta.dx)
            : null,
        onHorizontalDragEnd: isHorizontal
            ? (_) => setState(() => _dragging = false)
            : null,
        onVerticalDragStart: !isHorizontal
            ? (_) => setState(() => _dragging = true)
            : null,
        onVerticalDragUpdate: !isHorizontal
            ? (d) => widget.onDrag(d.delta.dy)
            : null,
        onVerticalDragEnd: !isHorizontal
            ? (_) => setState(() => _dragging = false)
            : null,
        child: SizedBox(
          width: isHorizontal ? widget.thickness : double.infinity,
          height: isHorizontal ? double.infinity : widget.thickness,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Đường kẻ mảnh chạy dọc/ngang toàn bộ thanh chia.
              Positioned.fill(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: isHorizontal ? 2 : double.infinity,
                    height: isHorizontal ? double.infinity : 2,
                    color: lineColor,
                  ),
                ),
              ),
              // Biểu tượng grip ở giữa — gợi ý có thể kéo đổi kích thước.
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.symmetric(
                  horizontal: isHorizontal ? 2 : 6,
                  vertical: isHorizontal ? 6 : 2,
                ),
                decoration: BoxDecoration(
                  color: widget.colorScheme.surface.withValues(
                    alpha: active ? 0.98 : 0.92,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? widget.colorScheme.primary.withValues(alpha: 0.45)
                        : widget.colorScheme.outline.withValues(alpha: 0.25),
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: widget.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: SizedBox(width: 4,height: 10,),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
