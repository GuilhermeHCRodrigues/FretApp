import 'package:flutter/material.dart';

/// Tokens de cor do FretApp.
///
/// Regra geral: as telas leem cores do `Theme.of(context).colorScheme`.
/// Use [AppCores] direto apenas quando o tema não tiver um papel equivalente
/// (status, mapa, ilustração).
abstract final class AppCores {
  // ── Marca ──────────────────────────────────────────────────────────────
  /// Seed do ColorScheme, ícones e destaques.
  /// NÃO usar com texto branco por cima (contraste 3,1:1).
  static const marca = Color(0xFF2196F3);

  /// Botões preenchidos, links e qualquer texto/ícone sobre azul (5,75:1).
  static const primaria = Color(0xFF1565C0);

  /// Indicador da NavigationBar/Rail, chips e containers.
  static const azulClaro = Color(0xFFD6E3FF);

  /// Texto e ícones sobre [azulClaro].
  static const sobreAzulClaro = Color(0xFF0D3B7A);

  // ── Superfícies ────────────────────────────────────────────────────────
  static const fundo = Color(0xFFF8F9FF);
  static const superficie = Color(0xFFFFFFFF);
  static const borda = Color(0xFFE1E6F0);

  // ── Texto ──────────────────────────────────────────────────────────────
  static const texto = Color(0xFF1A1C22);
  static const textoSecundario = Color(0xFF5A6273);

  // ── Status (verde e âmbar SÓ aqui) ─────────────────────────────────────
  static const sucesso = Color(0xFF2E7D32);
  static const sucessoFundo = Color(0xFFE8F5E9);
  static const atencao = Color(0xFFB26A00);
  static const atencaoFundo = Color(0xFFFFF3E0);
  static const erro = Color(0xFFC62828);
  static const erroFundo = Color(0xFFFFEBEE);
  static const neutro = Color(0xFF5A6273);
  static const neutroFundo = Color(0xFFEEF0F4);

  // ── Mapa (widgets/mapa_trajeto_demo.dart) ──────────────────────────────
  /// A rota usa a mesma cor da [primaria].
  static const mapaRota = primaria;
  static const mapaRotaEscura = Color(0xFF0D3B7A);
  static const mapaFundo = Color(0xFFFAFBFE);
  static const mapaQuadra = Color(0xFFE8EBF3);
  static const mapaQuadraAlt = Color(0xFFE5E9F2);
  static const mapaRua = Color(0xFFF8F9FD);
  static const mapaVerde = Color(0xFFC5EAC5);
  static const mapaVerdeEscuro = Color(0xFFBBE9BD);
  static const mapaAgua = Color(0xFF9DD9F5);
  static const mapaRotulo = Color(0xFF5A6273);
  static const mapaRotuloForte = Color(0xFF0D1B3A);
  static const mapaSombra = Color(0x66334E78);
  static const mapaHalo = Color(0x331565C0);
  static const mapaPainel = Color(0xF5FFFFFF);

  // ── Ilustração (widgets/ilustracao_onibus.dart) ────────────────────────
  static const ilustracaoCarroceria = Color(0xFF0E3E82);
  static const ilustracaoVidro = Color(0xFF125BA7);
  static const ilustracaoDetalhe = Color(0xFF1A70BC);
  static const ilustracaoClaro = Color(0xFFD4E8FD);
  static const ilustracaoMedio = Color(0xFF88B5E4);
  static const ilustracaoSombra = Color(0x333F7EBB);
  static const ilustracaoFarol = Color(0xFFFABB52);
}
