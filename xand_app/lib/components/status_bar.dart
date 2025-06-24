import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class StatusBar extends PositionComponent {
  final String label;
  final Paint _backgroundPaint = Paint()..color = Colors.grey.withOpacity(0.5);
  final Paint _foregroundPaint = Paint()..color = Colors.green;

  late TextComponent _textComponent;
  late RectangleComponent _backgroundBar;
  late RectangleComponent _foregroundBar;

  double _currentValue = 1.0;

  StatusBar({
    required this.label,
    required double initialValue,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size) {
    _currentValue = initialValue;
  }

  @override
  Future<void> onLoad() async {
    _textComponent = TextComponent(
      text: label,
      position: Vector2(0, -22),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );

    _backgroundBar = RectangleComponent(
      size: size,
      paint: _backgroundPaint,
    );

    _foregroundBar = RectangleComponent(
      size: Vector2(size.x * _currentValue, size.y),
      paint: _foregroundPaint,
    );

    await add(_backgroundBar);
    await add(_foregroundBar);
    await add(_textComponent);
  }

  void updateValue(double newValue) {
    _currentValue = newValue.clamp(0.0, 1.0);
    _foregroundBar.size.x = size.x * _currentValue;

    // Muda a cor da barra conforme o valor
    if (_currentValue < 0.3) {
      _foregroundPaint.color = Colors.red;
    } else if (_currentValue < 0.6) {
      _foregroundPaint.color = Colors.amber;
    } else {
      _foregroundPaint.color = Colors.green;
    }
  }
}