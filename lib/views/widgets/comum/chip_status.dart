import 'package:flutter/material.dart';

import '../../../tema/app_tema.dart';
import '../../../tema/cores_status.dart';

/// Etiqueta de status com as cores semânticas do tema.
///
/// Use os construtores nomeados para mapear direto o valor vindo do banco:
/// `ChipStatus.viagem(viagem.status)`, `ChipStatus.pagamento(p.status)`...
class ChipStatus extends StatelessWidget {
  const ChipStatus({
    super.key,
    required this.rotulo,
    required this.tom,
    this.icone,
  });

  ChipStatus.de(InfoStatus info, {Key? key, IconData? icone})
    : this(key: key, rotulo: info.rotulo, tom: info.tom, icone: icone);

  ChipStatus.viagem(String? status, {Key? key})
    : this.de(statusViagem(status), key: key);

  ChipStatus.mensalidade(String? status, {Key? key})
    : this.de(statusMensalidade(status), key: key);

  ChipStatus.pagamento(String? status, {Key? key})
    : this.de(statusPagamento(status), key: key);

  ChipStatus.embarque(String? status, {Key? key})
    : this.de(statusEmbarque(status), key: key);

  ChipStatus.trajeto(String? trajeto, {Key? key})
    : this.de(statusTrajeto(trajeto), key: key);

  final String rotulo;
  final TomStatus tom;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final cores = CoresStatus.of(context).de(tom);
    final estilo = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: cores.cor,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      label: 'Status: $rotulo',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cores.fundo,
          borderRadius: BorderRadius.circular(AppRaios.pequeno),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 14, color: cores.cor),
                const SizedBox(width: 4),
              ],
              Text(rotulo, style: estilo),
            ],
          ),
        ),
      ),
    );
  }
}
