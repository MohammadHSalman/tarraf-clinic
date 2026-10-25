import 'dart:typed_data';
import 'package:flutter/material.dart';

class CompareImages extends StatefulWidget {
  final Uint8List before, after;
  const CompareImages({super.key, required this.before, required this.after});
  @override
  State<CompareImages> createState() => _CompareImagesState();
}

class _CompareImagesState extends State<CompareImages> {
  double value = .5;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (c, b) => Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(widget.after, fit: BoxFit.contain),
              ClipRect(
                clipper: _Reveal(value),
                child: Image.memory(widget.before, fit: BoxFit.contain),
              ),
              Positioned(
                left: b.maxWidth * value,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              const Positioned(
                left: 8,
                top: 8,
                child: Chip(label: Text('قبل / Before')),
              ),
              const Positioned(
                right: 8,
                top: 8,
                child: Chip(label: Text('بعد / After')),
              ),
            ],
          ),
        ),
      ),
      Slider(value: value, onChanged: (v) => setState(() => value = v)),
    ],
  );
}

class _Reveal extends CustomClipper<Rect> {
  final double value;
  _Reveal(this.value);
  @override
  Rect getClip(Size s) => Rect.fromLTWH(0, 0, s.width * value, s.height);
  @override
  bool shouldReclip(_Reveal old) => old.value != value;
}
