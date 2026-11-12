import 'dart:async';

import 'package:flutter/material.dart';

import '../models/posicao_motorista.dart';
import '../models/viagem_do_dia.dart';
import '../services/motorista_servico.dart' as servico;
import '../tema/cores_status.dart';
import 'widgets/comum/chip_status.dart';
import 'widgets/mapa_motorista.dart';

/// Mapa do ônibus ao vivo para o passageiro, embutido no cartão da viagem.
///
/// Só leitura: não pede nem usa a localização do passageiro. Mostra o trajeto
/// planejado e, quando o motorista inicia a viagem, o ônibus em tempo real.
class MapaOnibusAoVivo extends StatefulWidget {
  const MapaOnibusAoVivo({
    super.key,
    this.trajeto = const [],
    this.pontos = const [],
    this.altura = 320,
    this.fonte = servico.acompanharOnibus,
    this.urlTiles = MapaMotorista.urlOpenStreetMap,
  });

  final List<Coordenada> trajeto;
  final List<PontoRota> pontos;
  final double altura;

  /// Posições dos ônibus em viagem (Supabase Realtime por padrão).
  final Stream<List<PosicaoMotorista>> Function() fonte;
  final String? urlTiles;

  /// Sem atualização por mais que isso, o sinal é considerado perdido.
  static const limiteSinal = Duration(seconds: 60);

  @override
  State<MapaOnibusAoVivo> createState() => _MapaOnibusAoVivoState();
}

class _MapaOnibusAoVivoState extends State<MapaOnibusAoVivo> {
  late Stream<List<PosicaoMotorista>> _posicoes = widget.fonte();
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    // Reavalia "atualizado há…" e a perda de sinal mesmo sem novos dados.
    _relogio = Timer.periodic(
      const Duration(seconds: 10),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  void _tentarDeNovo() => setState(() => _posicoes = widget.fonte());

  static PosicaoMotorista? _maisRecente(List<PosicaoMotorista> lista) {
    if (lista.isEmpty) return null;
    final ordenada = [...lista]
      ..sort(
        (a, b) => (b.atualizadoEm ?? DateTime(0)).compareTo(
          a.atualizadoEm ?? DateTime(0),
        ),
      );
    return ordenada.first;
  }

  static String _haQuanto(Duration d) {
    if (d.inSeconds < 15) return 'agora mesmo';
    if (d.inMinutes < 1) return 'há ${d.inSeconds} s';
    return 'há ${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return StreamBuilder<List<PosicaoMotorista>>(
      stream: _posicoes,
      builder: (context, snapshot) {
        final erro = snapshot.hasError;
        final posicao = snapshot.hasData ? _maisRecente(snapshot.data!) : null;
        final idade = posicao?.atualizadoEm == null
            ? null
            : DateTime.now().toUtc().difference(posicao!.atualizadoEm!.toUtc());
        final semSinal =
            idade != null && idade > MapaOnibusAoVivo.limiteSinal;

        final (String titulo, String detalhe, Widget? etiqueta) = switch (()) {
          _ when erro => (
            'Não foi possível acompanhar o ônibus',
            'Verifique sua conexão.',
            null,
          ),
          _ when !snapshot.hasData => ('Procurando o ônibus…', '', null),
          _ when posicao == null => (
            'O ônibus ainda não saiu',
            'Ele aparece no mapa assim que o motorista iniciar a viagem.',
            null,
          ),
          _ when semSinal => (
            'Sem sinal do ônibus',
            'Última posição ${_haQuanto(idade)}',
            const ChipStatus(rotulo: 'Sem sinal', tom: TomStatus.atencao),
          ),
          _ => (
            'Ônibus a caminho',
            idade == null ? 'Posição ao vivo' : 'Atualizado ${_haQuanto(idade)}',
            const ChipStatus(
              rotulo: 'Ao vivo',
              tom: TomStatus.sucesso,
              icone: Icons.circle,
            ),
          ),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MapaMotorista(
              altura: widget.altura,
              urlTiles: widget.urlTiles,
              posicao: semSinal ? null : posicao,
              trajeto: widget.trajeto,
              pontos: widget.pontos,
              seguirInicialmente: false,
              centroPadrao: MapaMotorista.regiaoOperacao,
              textoSemPosicao: semSinal
                  ? 'Sem sinal do ônibus'
                  : 'O ônibus ainda não saiu',
              iconeSemPosicao: Icons.directions_bus_outlined,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  erro ? Icons.cloud_off : Icons.directions_bus,
                  color: erro
                      ? tema.colorScheme.error
                      : tema.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: tema.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (detalhe.isNotEmpty)
                          Text(
                            detalhe,
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (erro)
                  TextButton(
                    onPressed: _tentarDeNovo,
                    child: const Text('Tentar de novo'),
                  )
                else
                  ?etiqueta,
              ],
            ),
          ],
        );
      },
    );
  }
}
