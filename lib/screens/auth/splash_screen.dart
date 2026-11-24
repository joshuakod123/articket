import 'package:flutter/material.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/stacking_loader.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.label = '서랍을 여는 중'});
  final String label;
  static const minimumHold = Duration(milliseconds: 650);
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 3),
          const Center(child: ArticketLogo(height: 68, vertical: true)),
          const Spacer(flex: 2),
          StackingLoader(size: 70, label: label),
          const Spacer(),
        ],
      ),
    ),
  );
}
