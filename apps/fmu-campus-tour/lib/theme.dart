import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color.fromARGB(255, 74, 203, 102),
  secondary: Color.fromARGB(255, 0, 56, 130),
  secondaryContainer: Color.fromARGB(255, 34, 101, 187),
  onPrimary: Color.fromARGB(255, 236, 255, 239),
  onSecondary: Color.fromARGB(255, 211, 233, 255),
  error: Colors.red,
  onError: Colors.white,
  background: Color.fromARGB(255, 248, 248, 248),
  onBackground: Colors.black,
  surface: Colors.white,
  onSurface: Colors.black,
  surfaceTint: Colors.transparent,
);

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color.fromARGB(255, 74, 203, 102),
  secondary: Color.fromARGB(255, 0, 56, 130),
  secondaryContainer: Color.fromARGB(255, 34, 101, 187),
  onPrimary: Color.fromARGB(255, 236, 255, 239),
  onSecondary: Color.fromARGB(255, 211, 233, 255),
  error: Colors.red,
  onError: Colors.white,
  background: Color.fromARGB(255, 32, 32, 32),
  onBackground: Colors.white,
  surface: Color.fromARGB(255, 42, 42, 42),
  onSurface: Colors.white,
  surfaceTint: Colors.transparent,
);

ThemeData get lightThemeData => ThemeData(
      dividerColor: const Color.fromARGB(255, 224, 224, 224),
      dividerTheme: const DividerThemeData(
        color: Color.fromARGB(255, 224, 224, 224),
      ),
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          ),
          backgroundColor: MaterialStateProperty.all(lightColorScheme.primary),
          foregroundColor:
              MaterialStateProperty.all(lightColorScheme.onPrimary),
          overlayColor: MaterialStateProperty.all(const Color(0x20FFFFFF)),
          shape: MaterialStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16.0)),
            ),
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: GoogleFonts.montserrat(
          color: Colors.black,
          fontSize: 24.0,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.montserrat(
          color: Colors.black,
          fontSize: 21.0,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.montserrat(
          color: Colors.black,
          fontSize: 15.0,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.montserrat(
          color: Colors.black,
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w500,
          color: Colors.black,
          fontSize: 16.0,
          letterSpacing: 1.1,
        ),
        labelMedium: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w500,
          color: Colors.black,
          fontSize: 14.0,
          letterSpacing: 1.5,
        ),
        labelSmall: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w500,
          color: Colors.black,
          fontSize: 13.0,
          letterSpacing: 1.5,
        ),
        bodyLarge: GoogleFonts.sourceSans3(
          color: Colors.black,
          fontSize: 17.0,
        ),
        bodyMedium: GoogleFonts.sourceSans3(
          color: Colors.black,
          fontSize: 16.0,
        ),
        bodySmall: GoogleFonts.sourceSans3(
          color: Colors.black,
          fontSize: 14.0,
        ),
      ),
      colorScheme: lightColorScheme,
      sliderTheme: const SliderThemeData(
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16.0),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.0),
      ),
      appBarTheme: const AppBarTheme(
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 24, 24, 24),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );

ThemeData get darkThemeData => ThemeData(
      dividerColor: const Color.fromARGB(255, 72, 72, 72),
      dividerTheme: const DividerThemeData(
        color: Color.fromARGB(255, 72, 72, 72),
      ),
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          ),
          backgroundColor: MaterialStateProperty.all(darkColorScheme.primary),
          foregroundColor: MaterialStateProperty.all(darkColorScheme.onPrimary),
          overlayColor: MaterialStateProperty.all(const Color(0x20FFFFFF)),
          shape: MaterialStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16.0)),
            ),
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 25.0,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 22.0,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontSize: 14.0,
          letterSpacing: 1.1,
        ),
        labelMedium: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontSize: 12.0,
          letterSpacing: 1.5,
        ),
        labelSmall: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontSize: 11.0,
          letterSpacing: 1.5,
        ),
        bodyLarge: GoogleFonts.sourceSans3(
          color: Colors.white,
          fontSize: 15.0,
        ),
        bodyMedium: GoogleFonts.sourceSans3(
          color: Colors.white,
          fontSize: 14.0,
        ),
        bodySmall: GoogleFonts.sourceSans3(
          color: Colors.white,
          fontSize: 12.0,
        ),
      ),
      colorScheme: darkColorScheme,
      sliderTheme: const SliderThemeData(
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16.0),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.0),
      ),
      appBarTheme: const AppBarTheme(
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 48, 48, 48),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
