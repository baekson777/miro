import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Analog 360° stick: direction + magnitude in [0, 1] written to [vector].
///
/// Clears to [Offset.zero] immediately on pointer up / cancel / dispose.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.vector,
    this.size = 128,
    /// Fraction of max travel ignored near center (anti-jitter).
    this.deadZone = 0.2,
  });

  /// Output: `Offset.zero` or a vector with length in (0, 1], any angle.
  final ValueNotifier<Offset> vector;
  final double size;
  final double deadZone;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  final ValueNotifier<Offset> _knob = ValueNotifier(Offset.zero);
  int? _pointer;
  bool _wasActive = false;

  double get _radius => widget.size / 2;
  double get _travel => _radius * 0.55;

  /// Direction (unit) × remapped magnitude after deadzone, clamped to travel.
  Offset _analogFromLocal(Offset local) {
    final center = Offset(_radius, _radius);
    final raw = local - center;
    final dist = raw.distance;
    if (dist <= 1e-6) return Offset.zero;

    final clampedDist = math.min(dist, _travel);
    final mag = (clampedDist / _travel).clamp(0.0, 1.0);
    if (mag < widget.deadZone) return Offset.zero;

    // Remap so just outside deadzone → ~0 speed, rim → 1.
    final dz = widget.deadZone;
    final remapped = ((mag - dz) / (1.0 - dz)).clamp(0.0, 1.0);
    final ux = raw.dx / dist;
    final uy = raw.dy / dist;
    return Offset(ux * remapped, uy * remapped);
  }

  void _applyLocal(Offset local) {
    final analog = _analogFromLocal(local);

    if (analog == Offset.zero) {
      _knob.value = Offset.zero;
    } else {
      // Knob follows finger direction, clamped to travel ring.
      _knob.value = Offset(analog.dx * _travel, analog.dy * _travel);
    }

    final active = analog != Offset.zero;
    if (active && !_wasActive) {
      HapticFeedback.selectionClick();
    }
    _wasActive = active;

    // Always publish — magnitude changes must reach the mover every frame.
    widget.vector.value = analog;
  }

  void _clearInput() {
    _pointer = null;
    _wasActive = false;
    _knob.value = Offset.zero;
    widget.vector.value = Offset.zero;
  }

  @override
  void dispose() {
    _knob.dispose();
    widget.vector.value = Offset.zero;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          _applyLocal(e.localPosition);
        },
        onPointerMove: (e) {
          // PointerRouter keeps delivering moves for this pointer id
          // even when the finger leaves the widget bounds.
          if (e.pointer != _pointer) return;
          _applyLocal(e.localPosition);
        },
        onPointerUp: (e) {
          if (e.pointer != _pointer) return;
          _clearInput();
        },
        onPointerCancel: (e) {
          if (e.pointer != _pointer) return;
          _clearInput();
        },
        child: ValueListenableBuilder<Offset>(
          valueListenable: _knob,
          builder: (context, knob, _) {
            return CustomPaint(
              painter: _JoystickPainter(
                knob: knob,
                active: knob.distance > 0.5,
                accent: accent,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knob,
    required this.active,
    required this.accent,
  });

  final Offset knob;
  final bool active;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;

    canvas.drawCircle(center, baseR, Paint()..color = const Color(0xFF1A1A1F));
    canvas.drawCircle(
      center,
      baseR,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Soft cross guides (orientation only — not 4-way snap).
    final guide = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(center.dx, center.dy - baseR * 0.7),
      Offset(center.dx, center.dy + baseR * 0.7),
      guide,
    );
    canvas.drawLine(
      Offset(center.dx - baseR * 0.7, center.dy),
      Offset(center.dx + baseR * 0.7, center.dy),
      guide,
    );

    final knobCenter = center + knob;
    final knobR = baseR * 0.32;
    canvas.drawCircle(
      knobCenter,
      knobR,
      Paint()..color = active ? accent : const Color(0xFFE8C547),
    );
    canvas.drawCircle(
      knobCenter,
      knobR,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) {
    return old.knob != knob || old.active != active || old.accent != accent;
  }
}
