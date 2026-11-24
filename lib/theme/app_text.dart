import 'package:flutter/material.dart';

/// Bundled fonts: every screen and exported card works on the first offline run.
class AppText {
  AppText._();
  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
    double spacing = 0,
  }) => TextStyle(
    fontFamily: 'AppSans',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.28,
    double spacing = -0.6,
  }) => ui(
    size: size,
    weight: weight,
    color: color,
    height: height,
    spacing: spacing,
  );
  static TextStyle wordmark({
    double size = 17,
    Color? color,
    double spacing = 3,
    FontWeight weight = FontWeight.w700,
  }) => ui(
    size: size,
    weight: weight,
    color: color,
    height: 1.1,
    spacing: spacing,
  );
  static TextStyle plate({
    double size = 30,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.15,
    double spacing = -0.4,
  }) => TextStyle(
    fontFamily: 'TicketSerif',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
  static TextStyle data({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double spacing = 0.8,
    double height = 1.3,
  }) => TextStyle(
    fontFamily: 'TicketMono',
    fontFamilyFallback: const ['AppSans'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );
  static TextStyle dymo({
    double size = 10,
    Color? color,
    double spacing = 2.6,
  }) =>
      data(size: size, color: color, spacing: spacing, weight: FontWeight.w700);
  static TextStyle hand({
    double size = 20,
    Color? color,
    double height = 1.3,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'TicketHand',
    fontSize: size,
    color: color,
    height: height,
    fontWeight: weight,
  );
  static TextStyle eyebrow({Color? color, double size = 10}) =>
      ui(size: size, color: color, weight: FontWeight.w600, spacing: 1.2);
}
