import 'dart:math' as math;

/// Leitura de GPS do motorista (sem depender do pacote de localização).
class PosicaoMotorista {
  const PosicaoMotorista(
    this.latitude,
    this.longitude, {
    this.rumo,
    this.precisao,
    this.atualizadoEm,
  });

  final double latitude;
  final double longitude;

  /// Direção em graus (0 = norte, sentido horário). `null` se desconhecida.
  final double? rumo;

  /// Raio de incerteza em metros.
  final double? precisao;

  /// Quando a leitura foi gravada no banco (só nas posições lidas do Supabase).
  final DateTime? atualizadoEm;

  PosicaoMotorista comRumo(double? novoRumo) =>
      PosicaoMotorista(
        latitude,
        longitude,
        rumo: novoRumo,
        precisao: precisao,
        atualizadoEm: atualizadoEm,
      );

  /// Distância aproximada em metros (haversine).
  double distanciaAte(PosicaoMotorista outra) {
    const raioTerra = 6371000.0;
    final dLat = _rad(outra.latitude - latitude);
    final dLng = _rad(outra.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(latitude)) *
            math.cos(_rad(outra.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * raioTerra * math.asin(math.sqrt(a));
  }

  /// Direção (graus) daqui até [outra].
  double rumoAte(PosicaoMotorista outra) {
    final lat1 = _rad(latitude);
    final lat2 = _rad(outra.latitude);
    final dLng = _rad(outra.longitude - longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _rad(double graus) => graus * math.pi / 180;
}
