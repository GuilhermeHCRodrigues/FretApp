import 'package:flutter/material.dart';

import 'app_cores.dart';

/// Par de cores (texto/ícone + fundo) de um status.
@immutable
class CorStatus {
  const CorStatus(this.cor, this.fundo);

  final Color cor;
  final Color fundo;

  static CorStatus? lerp(CorStatus? a, CorStatus? b, double t) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    return CorStatus(Color.lerp(a.cor, b.cor, t)!, Color.lerp(a.fundo, b.fundo, t)!);
  }
}

/// Semântica visual dos status. Só estes tons usam verde e âmbar no app.
enum TomStatus { informativo, sucesso, atencao, erro, neutro }

/// Extensão do tema com as cores de status.
///
/// Uso: `Theme.of(context).extension<CoresStatus>()!.de(TomStatus.sucesso)`
/// ou, mais simples, `CoresStatus.of(context).de(...)`.
@immutable
class CoresStatus extends ThemeExtension<CoresStatus> {
  const CoresStatus({
    required this.informativo,
    required this.sucesso,
    required this.atencao,
    required this.erro,
    required this.neutro,
  });

  static const claro = CoresStatus(
    informativo: CorStatus(AppCores.primaria, AppCores.azulClaro),
    sucesso: CorStatus(AppCores.sucesso, AppCores.sucessoFundo),
    atencao: CorStatus(AppCores.atencao, AppCores.atencaoFundo),
    erro: CorStatus(AppCores.erro, AppCores.erroFundo),
    neutro: CorStatus(AppCores.neutro, AppCores.neutroFundo),
  );

  final CorStatus informativo;
  final CorStatus sucesso;
  final CorStatus atencao;
  final CorStatus erro;
  final CorStatus neutro;

  static CoresStatus of(BuildContext context) =>
      Theme.of(context).extension<CoresStatus>() ?? claro;

  CorStatus de(TomStatus tom) => switch (tom) {
    TomStatus.informativo => informativo,
    TomStatus.sucesso => sucesso,
    TomStatus.atencao => atencao,
    TomStatus.erro => erro,
    TomStatus.neutro => neutro,
  };

  @override
  CoresStatus copyWith({
    CorStatus? informativo,
    CorStatus? sucesso,
    CorStatus? atencao,
    CorStatus? erro,
    CorStatus? neutro,
  }) => CoresStatus(
    informativo: informativo ?? this.informativo,
    sucesso: sucesso ?? this.sucesso,
    atencao: atencao ?? this.atencao,
    erro: erro ?? this.erro,
    neutro: neutro ?? this.neutro,
  );

  @override
  CoresStatus lerp(CoresStatus? other, double t) {
    if (other == null) return this;
    return CoresStatus(
      informativo: CorStatus.lerp(informativo, other.informativo, t)!,
      sucesso: CorStatus.lerp(sucesso, other.sucesso, t)!,
      atencao: CorStatus.lerp(atencao, other.atencao, t)!,
      erro: CorStatus.lerp(erro, other.erro, t)!,
      neutro: CorStatus.lerp(neutro, other.neutro, t)!,
    );
  }
}

/// Tom + rótulo pronto para exibir.
typedef InfoStatus = ({TomStatus tom, String rotulo});

InfoStatus _desconhecido(String? valor) =>
    (tom: TomStatus.neutro, rotulo: valor == null || valor.isEmpty ? '—' : valor);

// ── Mapeamento dos enums do banco ──────────────────────────────────────────
// programada → primária; finais positivos → sucesso;
// pendente/em andamento → atenção; negativos → erro.

/// `viagens.status`
InfoStatus statusViagem(String? status) => switch (status) {
  'programada' => (tom: TomStatus.informativo, rotulo: 'Programada'),
  'em_andamento' => (tom: TomStatus.atencao, rotulo: 'Em andamento'),
  'finalizada' => (tom: TomStatus.sucesso, rotulo: 'Finalizada'),
  'cancelada' => (tom: TomStatus.erro, rotulo: 'Cancelada'),
  _ => _desconhecido(status),
};

/// `mensalidades.status`
InfoStatus statusMensalidade(String? status) => switch (status) {
  'pendente' => (tom: TomStatus.atencao, rotulo: 'Pendente'),
  'paga' => (tom: TomStatus.sucesso, rotulo: 'Paga'),
  'vencida' => (tom: TomStatus.erro, rotulo: 'Vencida'),
  'cancelada' => (tom: TomStatus.erro, rotulo: 'Cancelada'),
  _ => _desconhecido(status),
};

/// `pagamentos.status`
InfoStatus statusPagamento(String? status) => switch (status) {
  'pendente' => (tom: TomStatus.atencao, rotulo: 'Pendente'),
  'aprovado' => (tom: TomStatus.sucesso, rotulo: 'Aprovado'),
  'rejeitado' => (tom: TomStatus.erro, rotulo: 'Rejeitado'),
  'cancelado' => (tom: TomStatus.erro, rotulo: 'Cancelado'),
  'estornado' => (tom: TomStatus.erro, rotulo: 'Estornado'),
  _ => _desconhecido(status),
};

/// `embarques.status`
InfoStatus statusEmbarque(String? status) => switch (status) {
  'embarcado' => (tom: TomStatus.sucesso, rotulo: 'Embarcado'),
  'nao_embarcado' => (tom: TomStatus.erro, rotulo: 'Não embarcado'),
  _ => _desconhecido(status),
};

/// `confirmacoes_presenca.trajeto`
InfoStatus statusTrajeto(String? trajeto) => switch (trajeto) {
  'ida_volta' => (tom: TomStatus.sucesso, rotulo: 'Ida e volta'),
  'ida' => (tom: TomStatus.informativo, rotulo: 'Só ida'),
  'volta' => (tom: TomStatus.informativo, rotulo: 'Só volta'),
  'nao_vai' => (tom: TomStatus.erro, rotulo: 'Não vai'),
  _ => _desconhecido(trajeto),
};
