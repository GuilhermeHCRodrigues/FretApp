import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/posicao_motorista.dart';
import '../../models/viagem_do_dia.dart';
import '../../tema/app_cores.dart';
import '../../tema/app_tema.dart';

/// Mapa da viagem (OpenStreetMap via flutter_map), usado pelo motorista e
/// pelo passageiro.
///
/// - [trajeto] e [pontos]: rota planejada (linha clara) e paradas numeradas.
/// - [posicao]: ônibus ao vivo (seta girando conforme o rumo).
/// - [rastro]: caminho já percorrido (linha forte).
/// - Ao arrastar, para de seguir o ônibus e aparece "Centralizar".
class MapaMotorista extends StatefulWidget {
  const MapaMotorista({
    super.key,
    required this.posicao,
    this.rastro = const [],
    this.trajeto = const [],
    this.pontos = const [],
    this.altura,
    this.aoCompartilhar,
    this.aguardandoGps = false,
    this.seguirInicialmente = true,
    this.urlTiles = urlOpenStreetMap,
    this.textoSemPosicao = 'Compartilhe sua localização para ver o mapa',
    this.iconeSemPosicao = Icons.map_outlined,
    this.centroPadrao,
  });

  /// Região de operação (entre Santa Isabel e Mogi das Cruzes - SP).
  static const regiaoOperacao = Coordenada(-23.43, -46.20);

  /// Servidor de tiles. Para produção, troque por um provedor com chave
  /// (MapTiler, Mapbox, Stadia…): o OpenStreetMap público não é para uso
  /// intenso. `null` desliga os tiles (útil em testes).
  static const urlOpenStreetMap =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final PosicaoMotorista? posicao;
  final List<PosicaoMotorista> rastro;
  final List<Coordenada> trajeto;
  final List<PontoRota> pontos;
  final double? altura;

  /// Botão "Compartilhar localização" quando ainda não há posição.
  final VoidCallback? aoCompartilhar;

  /// Permissão concedida, esperando a primeira leitura do GPS.
  final bool aguardandoGps;

  /// `true`: câmera começa seguindo o ônibus (motorista).
  /// `false`: começa mostrando o trajeto inteiro (passageiro).
  final bool seguirInicialmente;
  final String? urlTiles;

  /// Mensagem quando ainda não há posição do ônibus.
  final String textoSemPosicao;
  final IconData iconeSemPosicao;

  /// Se informado, o mapa aparece mesmo sem ônibus e sem trajeto,
  /// centralizado aqui (visão da região).
  final Coordenada? centroPadrao;

  @override
  State<MapaMotorista> createState() => _MapaMotoristaState();
}

class _MapaMotoristaState extends State<MapaMotorista> {
  static const _zoomSeguindo = 16.0;
  final _controle = MapController();
  late bool _seguindo = widget.seguirInicialmente;
  bool _pronto = false;

  List<LatLng> get _pontosDaRota => [
    for (final c in widget.trajeto) LatLng(c.latitude, c.longitude),
    for (final p in widget.pontos)
      if (p.coordenada != null)
        LatLng(p.coordenada!.latitude, p.coordenada!.longitude),
  ];

  @override
  void didUpdateWidget(MapaMotorista antigo) {
    super.didUpdateWidget(antigo);
    final nova = widget.posicao;
    if (nova == null || !_pronto || nova == antigo.posicao) return;
    if (_seguindo) {
      _controle.move(
        _ponto(nova),
        antigo.posicao == null
            ? math.max(_controle.camera.zoom, _zoomSeguindo)
            : _controle.camera.zoom,
      );
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  static LatLng _ponto(PosicaoMotorista p) => LatLng(p.latitude, p.longitude);

  void _centralizar() {
    final posicao = widget.posicao;
    if (posicao == null) return;
    setState(() => _seguindo = true);
    _controle.move(_ponto(posicao), math.max(_controle.camera.zoom, 15));
  }

  void _verTrajeto() {
    final rota = _pontosDaRota;
    if (rota.length < 2) return;
    setState(() => _seguindo = false);
    _controle.fitCamera(
      CameraFit.coordinates(
        coordinates: rota,
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final posicao = widget.posicao;
    final rota = _pontosDaRota;
    final centro = widget.centroPadrao;
    final temMapa = posicao != null || rota.length >= 2 || centro != null;

    final Widget conteudo;
    if (!temMapa) {
      conteudo = _SemPosicao(
        aguardando: widget.aguardandoGps,
        aoCompartilhar: widget.aoCompartilhar,
        texto: widget.textoSemPosicao,
        icone: widget.iconeSemPosicao,
      );
    } else {
      final enquadrarRota = rota.length >= 2 && (posicao == null || !_seguindo);
      conteudo = Stack(
        children: [
          FlutterMap(
            mapController: _controle,
            options: MapOptions(
              initialCenter: posicao != null
                  ? _ponto(posicao)
                  : rota.isNotEmpty
                  ? rota.first
                  : LatLng(centro!.latitude, centro.longitude),
              initialZoom: posicao == null && rota.isEmpty
                  ? 11
                  : _zoomSeguindo,
              initialCameraFit: enquadrarRota
                  ? CameraFit.coordinates(
                      coordinates: [
                        ...rota,
                        if (posicao != null) _ponto(posicao),
                      ],
                      padding: const EdgeInsets.all(40),
                    )
                  : null,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () => _pronto = true,
              onPositionChanged: (_, comGesto) {
                if (comGesto && _seguindo) setState(() => _seguindo = false);
              },
            ),
            children: [
              if (widget.urlTiles != null)
                TileLayer(
                  urlTemplate: widget.urlTiles,
                  userAgentPackageName: 'com.example.fretapp',
                  maxNativeZoom: 19,
                ),
              if (widget.trajeto.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        for (final c in widget.trajeto)
                          LatLng(c.latitude, c.longitude),
                      ],
                      strokeWidth: 5,
                      color: AppCores.mapaRota.withValues(alpha: .45),
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              if (widget.rastro.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [for (final p in widget.rastro) _ponto(p)],
                      strokeWidth: 6,
                      color: AppCores.mapaRota,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              if (posicao?.precisao != null && posicao!.precisao! > 8)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _ponto(posicao),
                      radius: posicao.precisao!,
                      useRadiusInMeter: true,
                      color: AppCores.mapaHalo,
                      borderColor: AppCores.mapaRota.withValues(alpha: .3),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final (i, p) in widget.pontos.indexed)
                    if (p.coordenada != null)
                      Marker(
                        point: LatLng(
                          p.coordenada!.latitude,
                          p.coordenada!.longitude,
                        ),
                        width: 32,
                        height: 32,
                        child: Tooltip(
                          message: p.horario == null
                              ? p.nome
                              : '${p.horario} · ${p.nome}',
                          child: _MarcadorPonto(
                            numero: i + 1,
                            destino: i == widget.pontos.length - 1,
                          ),
                        ),
                      ),
                  if (posicao != null)
                    Marker(
                      point: _ponto(posicao),
                      width: 48,
                      height: 48,
                      child: _MarcadorVeiculo(rumo: posicao.rumo),
                    ),
                ],
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Sem posição do ônibus ainda: aviso no topo, mapa continua visível.
          if (posicao == null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _AvisoSemPosicao(
                aguardando: widget.aguardandoGps,
                texto: widget.textoSemPosicao,
                icone: widget.iconeSemPosicao,
                aoCompartilhar: widget.aoCompartilhar,
              ),
            ),

          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 8,
              children: [
                if (rota.length >= 2)
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Ver trajeto inteiro',
                    onPressed: _verTrajeto,
                    backgroundColor: cores.surfaceContainerLowest,
                    foregroundColor: cores.primary,
                    child: const Icon(Icons.route),
                  ),
                if (posicao != null && !_seguindo)
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: _centralizar,
                    backgroundColor: cores.surfaceContainerLowest,
                    foregroundColor: cores.primary,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Centralizar'),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Semantics(
      label: 'Mapa com a posição do ônibus',
      container: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRaios.grande),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppCores.mapaFundo,
            border: Border.all(color: cores.outlineVariant),
            borderRadius: BorderRadius.circular(AppRaios.grande),
          ),
          child: SizedBox(height: widget.altura ?? 320, child: conteudo),
        ),
      ),
    );
  }
}

/// Seta de navegação girando conforme o rumo (ou ônibus, se parado).
class _MarcadorVeiculo extends StatelessWidget {
  const _MarcadorVeiculo({required this.rumo});
  final double? rumo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppCores.mapaSombra,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppCores.mapaRota,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: rumo == null
                ? const Icon(Icons.directions_bus, color: Colors.white, size: 22)
                : Transform.rotate(
                    angle: rumo! * math.pi / 180,
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Parada numerada; o destino ganha uma bandeira.
class _MarcadorPonto extends StatelessWidget {
  const _MarcadorPonto({required this.numero, required this.destino});
  final int numero;
  final bool destino;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppCores.mapaRotaEscura,
      fontWeight: FontWeight.w800,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppCores.mapaRotaEscura, width: 2.5),
        boxShadow: const [
          BoxShadow(color: AppCores.mapaSombra, blurRadius: 4),
        ],
      ),
      child: Center(
        child: destino
            ? const Icon(Icons.flag, size: 16, color: AppCores.mapaRotaEscura)
            : Text('$numero', style: estilo),
      ),
    );
  }
}

class _AvisoSemPosicao extends StatelessWidget {
  const _AvisoSemPosicao({
    required this.aguardando,
    required this.texto,
    required this.icone,
    this.aoCompartilhar,
  });
  final bool aguardando;
  final String texto;
  final IconData icone;
  final VoidCallback? aoCompartilhar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (aguardando)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icone, color: tema.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                aguardando ? 'Buscando sinal de GPS…' : texto,
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!aguardando && aoCompartilhar != null)
              TextButton(
                onPressed: aoCompartilhar,
                child: const Text('Compartilhar localização'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SemPosicao extends StatelessWidget {
  const _SemPosicao({
    required this.aguardando,
    required this.texto,
    required this.icone,
    this.aoCompartilhar,
  });
  final bool aguardando;
  final String texto;
  final IconData icone;
  final VoidCallback? aoCompartilhar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (aguardando)
              const CircularProgressIndicator()
            else
              Icon(icone, size: 48, color: tema.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              aguardando ? 'Buscando sinal de GPS…' : texto,
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!aguardando && aoCompartilhar != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: aoCompartilhar,
                icon: const Icon(Icons.my_location),
                label: const Text('Compartilhar localização'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
