import '../tema/cores_status.dart';

/// Situação de um passageiro na competência (mês) consultada.
enum SituacaoPagamento {
  pago('Pago', TomStatus.sucesso),
  pendente('A vencer', TomStatus.atencao),
  atrasado('Atrasado', TomStatus.erro),
  /// Ainda não assinou: deve a mensalidade, mas o Stripe não gerou cobrança.
  emAberto('Em aberto', TomStatus.atencao),
  cancelada('Cancelada', TomStatus.neutro),

  /// Cadastro sem login: deve a mensalidade, mas precisa do acesso ao app
  /// para assinar e pagar.
  semAcesso('Sem acesso ao app', TomStatus.atencao);

  const SituacaoPagamento(this.rotulo, this.tom);

  final String rotulo;
  final TomStatus tom;

  InfoStatus get info => (tom: tom, rotulo: rotulo);

  /// Quem conta como "não pagou" no filtro. Cancelada não é dívida.
  bool get naoPagou => switch (this) {
    pendente || atrasado || emAberto || semAcesso => true,
    pago || cancelada => false,
  };
}

/// Filtro de "Status" da tabela do Financeiro.
enum FiltroPagamento {
  todos('Todos'),
  pagaram('Pagaram'),
  naoPagaram('Não pagaram'),
  atrasados('Atrasados');

  const FiltroPagamento(this.rotulo);

  final String rotulo;

  bool aceita(SituacaoPagamento s) => switch (this) {
    todos => true,
    pagaram => s == SituacaoPagamento.pago,
    naoPagaram => s.naoPagou,
    atrasados => s == SituacaoPagamento.atrasado,
  };
}

/// `assinaturas_stripe.status` → rótulo e tom.
InfoStatus statusAssinatura(String? status) => switch (status) {
  'active' => (tom: TomStatus.sucesso, rotulo: 'Ativa'),
  'trialing' => (tom: TomStatus.informativo, rotulo: 'Em teste'),
  'past_due' => (tom: TomStatus.erro, rotulo: 'Em atraso'),
  'unpaid' => (tom: TomStatus.erro, rotulo: 'Não paga'),
  'incomplete' => (tom: TomStatus.atencao, rotulo: 'Incompleta'),
  'incomplete_expired' => (tom: TomStatus.neutro, rotulo: 'Expirada'),
  'paused' => (tom: TomStatus.neutro, rotulo: 'Pausada'),
  'canceled' => (tom: TomStatus.neutro, rotulo: 'Cancelada'),
  _ => (tom: TomStatus.atencao, rotulo: 'Não assinou'),
};

/// Assinatura que gera cobranças (o Stripe ainda vai cobrar).
bool assinaturaEmVigor(String? status) =>
    const {'active', 'trialing', 'past_due', 'unpaid'}.contains(status);

/// Uma linha da tabela: um passageiro e a mensalidade dele no mês.
class LinhaFinanceira {
  const LinhaFinanceira({
    required this.chave,
    required this.nome,
    required this.situacao,
    this.perfilId,
    this.telefone,
    this.instituicao,
    this.valorCentavos,
    this.vencimento,
    this.vencimentoTexto,
    this.pagoEm,
    this.statusAssinatura,
  });

  /// Id estável da linha (perfil, ou cadastro quando não há login).
  final String chave;
  final String? perfilId;
  final String nome;
  final String? telefone;
  final String? instituicao;
  final SituacaoPagamento situacao;
  /// Valor da mensalidade do mês; sem cobrança gerada, o valor vigente.
  final int? valorCentavos;
  final DateTime? vencimento;

  /// Texto da coluna Vencimento quando ainda não há data ("Ao assinar").
  final String? vencimentoTexto;
  final DateTime? pagoEm;
  final String? statusAssinatura;
}

/// Dados brutos lidos do Supabase para uma competência.
class DadosFinanceiros {
  const DadosFinanceiros({
    this.perfis = const [],
    this.cadastros = const [],
    this.mensalidades = const [],
    this.assinaturas = const [],
    this.valorPadraoCentavos,
  });

  /// `perfis` com tipo = passageiro (contas de login).
  final List<Map<String, dynamic>> perfis;

  /// `passageiros` ativos (cadastro do administrador), com `perfil_id`.
  final List<Map<String, dynamic>> cadastros;

  /// `mensalidades` da competência, com `pagamentos(...)`.
  final List<Map<String, dynamic>> mensalidades;

  /// `assinaturas_stripe` (passageiro_id, status, periodo_fim).
  final List<Map<String, dynamic>> assinaturas;

  /// Valor vigente (`configuracao_mensalidade`): o que todo cadastrado deve
  /// enquanto o Stripe não gerou a cobrança do mês.
  final int? valorPadraoCentavos;
}

String? _texto(Object? valor) {
  final t = valor?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

DateTime? _data(Object? valor) =>
    valor == null ? null : DateTime.tryParse(valor.toString())?.toLocal();

/// Situação a partir de `mensalidades.status` e do vencimento.
SituacaoPagamento situacaoDaMensalidade(
  Map<String, dynamic>? mensalidade,
  DateTime hoje,
) {
  if (mensalidade == null) return SituacaoPagamento.emAberto;
  final dia = DateTime(hoje.year, hoje.month, hoje.day);
  final vencimento = _data(mensalidade['vencimento']);
  return switch (mensalidade['status']) {
    'paga' => SituacaoPagamento.pago,
    'vencida' => SituacaoPagamento.atrasado,
    'cancelada' => SituacaoPagamento.cancelada,
    _ when vencimento != null && vencimento.isBefore(dia) =>
      SituacaoPagamento.atrasado,
    _ => SituacaoPagamento.pendente,
  };
}

/// Data do último pagamento aprovado da mensalidade.
DateTime? _ultimoPagamento(Map<String, dynamic>? mensalidade) {
  final pagamentos = (mensalidade?['pagamentos'] as List?) ?? const [];
  DateTime? ultimo;
  for (final p in pagamentos.cast<Map>()) {
    if (p['status'] != 'aprovado') continue;
    final data = _data(p['pago_em']);
    if (data != null && (ultimo == null || data.isAfter(ultimo))) ultimo = data;
  }
  return ultimo;
}

/// Junta contas, cadastros, mensalidades e assinaturas: uma linha por pessoa.
///
/// - Todo passageiro cadastrado deve a mensalidade: sem cobrança no mês, a
///   linha mostra o valor vigente ([valorPadraoCentavos]) como em aberto.
/// - Toda conta de passageiro (`perfis`) aparece, com ou sem cadastro.
/// - Cadastro sem login aparece como "Sem acesso ao app" (precisa do login
///   para assinar).
/// - Nome/telefone do cadastro têm prioridade (são os do administrador).
List<LinhaFinanceira> montarLinhas(
  DadosFinanceiros dados,
  DateTime hoje, {
  int? valorPadraoCentavos,
}) {
  final valorPadrao = dados.valorPadraoCentavos ?? valorPadraoCentavos;
  final mensalidadePorPerfil = {
    for (final m in dados.mensalidades) m['passageiro_id'] as String: m,
  };
  final assinaturaPorPerfil = {
    for (final a in dados.assinaturas) a['passageiro_id'] as String: a,
  };
  final cadastroPorPerfil = <String, Map<String, dynamic>>{};
  final cadastrosSemLogin = <Map<String, dynamic>>[];
  for (final c in dados.cadastros) {
    final perfilId = c['perfil_id'] as String?;
    if (perfilId == null) {
      cadastrosSemLogin.add(c);
    } else {
      cadastroPorPerfil[perfilId] = c;
    }
  }

  LinhaFinanceira daConta(Map<String, dynamic> p) {
    final id = p['id'] as String;
    final cadastro = cadastroPorPerfil[id];
    final mensalidade = mensalidadePorPerfil[id];
    final assinatura = assinaturaPorPerfil[id];
    final status = assinatura?['status'] as String?;
    final nome =
        _texto(cadastro?['nome']) ??
        _texto(p['nome_completo']) ??
        'Passageiro sem nome';
    final telefone = _texto(cadastro?['telefone']) ?? _texto(p['telefone']);

    if (mensalidade != null) {
      return LinhaFinanceira(
        chave: id,
        perfilId: id,
        nome: nome,
        telefone: telefone,
        instituicao: _texto(p['instituicao']),
        situacao: situacaoDaMensalidade(mensalidade, hoje),
        valorCentavos:
            (mensalidade['valor_centavos'] as num?)?.toInt() ?? valorPadrao,
        vencimento: _data(mensalidade['vencimento']),
        pagoEm: _ultimoPagamento(mensalidade),
        statusAssinatura: status,
      );
    }

    // Sem cobrança no mês. Assinatura em vigor: o Stripe vai cobrar na
    // renovação (periodo_fim). Sem assinatura: deve, e paga ao assinar.
    final emVigor = assinaturaEmVigor(status);
    final renovacao = emVigor ? _data(assinatura?['periodo_fim']) : null;
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    return LinhaFinanceira(
      chave: id,
      perfilId: id,
      nome: nome,
      telefone: telefone,
      instituicao: _texto(p['instituicao']),
      situacao: !emVigor
          ? SituacaoPagamento.emAberto
          : renovacao != null && renovacao.isBefore(dia)
          ? SituacaoPagamento.atrasado
          : SituacaoPagamento.pendente,
      valorCentavos: valorPadrao,
      vencimento: renovacao,
      vencimentoTexto: emVigor ? 'Na renovação' : 'Ao assinar',
      statusAssinatura: status,
    );
  }

  final linhas = <LinhaFinanceira>[
    for (final p in dados.perfis) daConta(p),
    for (final c in cadastrosSemLogin)
      LinhaFinanceira(
        chave: 'cadastro:${c['id']}',
        nome: _texto(c['nome']) ?? 'Passageiro sem nome',
        telefone: _texto(c['telefone']),
        situacao: SituacaoPagamento.semAcesso,
        valorCentavos: valorPadrao,
        vencimentoTexto: 'Ao assinar',
      ),
  ];

  linhas.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  return linhas;
}

/// Totais da competência (todo cadastrado deve a mensalidade).
class ResumoFinanceiro {
  const ResumoFinanceiro({
    required this.total,
    required this.pagaram,
    required this.naoPagaram,
    required this.atrasados,
    required this.recebidoCentavos,
    required this.emAbertoCentavos,
  });

  factory ResumoFinanceiro.de(List<LinhaFinanceira> linhas) {
    var pagaram = 0, naoPagaram = 0, atrasados = 0;
    var recebido = 0, emAberto = 0;
    for (final l in linhas) {
      final valor = l.valorCentavos ?? 0;
      if (l.situacao == SituacaoPagamento.pago) {
        pagaram++;
        recebido += valor;
      } else if (l.situacao.naoPagou) {
        naoPagaram++;
        emAberto += valor;
      }
      if (l.situacao == SituacaoPagamento.atrasado) atrasados++;
    }
    return ResumoFinanceiro(
      total: linhas.length,
      pagaram: pagaram,
      naoPagaram: naoPagaram,
      atrasados: atrasados,
      recebidoCentavos: recebido,
      emAbertoCentavos: emAberto,
    );
  }

  final int total;
  final int pagaram;
  final int naoPagaram;
  final int atrasados;
  final int recebidoCentavos;
  final int emAbertoCentavos;
}

/// R$ 1.234,56
String formatarCentavos(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final reais = (abs ~/ 100).toString();
  final cent = (abs % 100).toString().padLeft(2, '0');
  final milhar = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) milhar.write('.');
    milhar.write(reais[i]);
  }
  return '${negativo ? '-' : ''}R\$ $milhar,$cent';
}

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "novembro de 2026"
String formatarCompetencia(DateTime mes) =>
    '${_meses[mes.month - 1]} de ${mes.year}';

/// 05/11/2026
String formatarData(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/${data.year}';
