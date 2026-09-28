// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class SosyoScreen extends StatefulWidget {
  const SosyoScreen({super.key});

  @override
  State<SosyoScreen> createState() => _SosyoScreenState();
}

class _SosyoScreenState extends State<SosyoScreen> {
  static const String _viewType = 'sosyo-web-frame';
  static bool _viewRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!_viewRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(
        'sosyo-web-frame',
        (int viewId) => html.IFrameElement()
          ..src = 'sosyo/index.html'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
      _viewRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'SoSYo 🌟',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri',
        ),
      ),
      body: const HtmlElementView(viewType: _viewType),
    );
  }
}
