import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: Colors.white,
  fontFamily: 'Cairo',

  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    onSecondary: AppColors.onSecondary,
  ),

  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: AppColors.onSurface,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.onSurface),
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.onPrimary,
    ),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: AppColors.onSurface),
    titleTextStyle: TextStyle(
      color: AppColors.onSurface,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.grey),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.grey),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    filled: true,
    fillColor: AppColors.surface,
  ),
);
