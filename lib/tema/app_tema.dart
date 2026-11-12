import 'package:flutter/material.dart';

import 'app_cores.dart';
import 'cores_status.dart';

/// Raios de borda permitidos no app: só 8, 12 e 16.
abstract final class AppRaios {
  static const pequeno = 8.0;
  static const medio = 12.0;
  static const grande = 16.0;
}

/// Breakpoint único: >= 900 px usa NavigationRail, abaixo NavigationBar.
abstract final class AppBreakpoints {
  static const desktop = 900.0;

  static bool ehDesktop(double largura) => largura >= desktop;
}

/// ThemeData único do FretApp.
abstract final class AppTema {
  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppCores.marca,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppCores.primaria,
      onPrimary: Colors.white,
      primaryContainer: AppCores.azulClaro,
      onPrimaryContainer: AppCores.sobreAzulClaro,
      secondaryContainer: AppCores.azulClaro,
      onSecondaryContainer: AppCores.sobreAzulClaro,
      surface: AppCores.fundo,
      onSurface: AppCores.texto,
      onSurfaceVariant: AppCores.textoSecundario,
      surfaceContainerLowest: AppCores.superficie,
      surfaceContainerLow: AppCores.superficie,
      outline: AppCores.textoSecundario,
      outlineVariant: AppCores.borda,
      error: AppCores.erro,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: esquema);
    final texto = base.textTheme.apply(
      bodyColor: AppCores.texto,
      displayColor: AppCores.texto,
    );

    const raioPequeno = BorderRadius.all(Radius.circular(AppRaios.pequeno));
    const raioMedio = BorderRadius.all(Radius.circular(AppRaios.medio));
    const raioGrande = BorderRadius.all(Radius.circular(AppRaios.grande));

    const formaBotao = RoundedRectangleBorder(borderRadius: raioMedio);
    const tamanhoBotao = Size(64, 48);

    return base.copyWith(
      scaffoldBackgroundColor: AppCores.fundo,
      textTheme: texto,
      dividerTheme: const DividerThemeData(
        color: AppCores.borda,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppCores.textoSecundario),

      appBarTheme: AppBarTheme(
        backgroundColor: AppCores.superficie,
        foregroundColor: AppCores.texto,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: const Border(bottom: BorderSide(color: AppCores.borda)),
        titleTextStyle: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),

      cardTheme: const CardThemeData(
        color: AppCores.superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: raioGrande,
          side: BorderSide(color: AppCores.borda),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppCores.superficie,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: raioMedio,
          borderSide: BorderSide(color: AppCores.borda),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: raioMedio,
          borderSide: BorderSide(color: AppCores.borda),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: raioMedio,
          borderSide: BorderSide(color: AppCores.primaria, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: raioMedio,
          borderSide: BorderSide(color: AppCores.erro),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: raioMedio,
          borderSide: BorderSide(color: AppCores.erro, width: 2),
        ),
        labelStyle: texto.bodyLarge?.copyWith(color: AppCores.textoSecundario),
        hintStyle: texto.bodyLarge?.copyWith(color: AppCores.textoSecundario),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppCores.primaria,
          foregroundColor: Colors.white,
          minimumSize: tamanhoBotao,
          shape: formaBotao,
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppCores.primaria,
          minimumSize: tamanhoBotao,
          shape: formaBotao,
          side: const BorderSide(color: AppCores.borda),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppCores.primaria,
          shape: formaBotao,
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppCores.superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppCores.azulClaro,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected)
                ? AppCores.primaria
                : AppCores.textoSecundario,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => texto.labelMedium?.copyWith(
            color: estados.contains(WidgetState.selected)
                ? AppCores.primaria
                : AppCores.textoSecundario,
            fontWeight: estados.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppCores.superficie,
        indicatorColor: AppCores.azulClaro,
        selectedIconTheme: const IconThemeData(color: AppCores.primaria),
        unselectedIconTheme: const IconThemeData(color: AppCores.textoSecundario),
        selectedLabelTextStyle: texto.labelLarge?.copyWith(
          color: AppCores.primaria,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: texto.labelLarge?.copyWith(
          color: AppCores.textoSecundario,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppCores.superficie,
        selectedColor: AppCores.azulClaro,
        side: const BorderSide(color: AppCores.borda),
        shape: const RoundedRectangleBorder(borderRadius: raioPequeno),
        labelStyle: texto.labelLarge?.copyWith(color: AppCores.texto),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: raioMedio),
        backgroundColor: AppCores.texto,
        contentTextStyle: texto.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppCores.azulClaro,
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppCores.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: raioGrande),
      ),

      listTileTheme: const ListTileThemeData(
        selectedColor: AppCores.primaria,
        selectedTileColor: AppCores.azulClaro,
        iconColor: AppCores.textoSecundario,
        shape: RoundedRectangleBorder(borderRadius: raioMedio),
      ),

      extensions: const [CoresStatus.claro],
    );
  }
}
