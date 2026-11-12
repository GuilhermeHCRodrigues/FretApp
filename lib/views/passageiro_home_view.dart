import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/viagem_do_dia.dart';
import '../services/motorista_servico.dart' show buscarViagemDoDia;
import 'acompanhar_onibus_view.dart';
import 'widgets/comum/chip_status.dart';
import 'widgets/comum/estados.dart';

class PassageiroHomeView extends StatefulWidget {
  const PassageiroHomeView({super.key});

  @override
  State<PassageiroHomeView> createState() => _PassageiroHomeViewState();
}

class _PassageiroHomeViewState extends State<PassageiroHomeView>
    with WidgetsBindingObserver {
  int paginaSelecionada = 0;

  static const azul = Color(0xFF1D4ED8);
  static const azulEscuro = Color(0xFF172554);
  static const fundo = Color(0xFFF5F7FB);

  // Mesmo formato da constraint do banco (perfis.telefone).
  static final regexTelefone = RegExp(r'^[0-9()+ .-]{8,20}$');

  final supabase = Supabase.instance.client;

  // Sempre lê o usuário atual (pode ficar nulo se a sessão expirar).
  User? get usuario => supabase.auth.currentUser;

  // ESTADO CARREGADO DO SUPABASE

  bool carregando = true;
  String? erroCarregamento;

  // false = não existe linha em public.perfis para este usuário.
  bool perfilExiste = false;

  String? nomeCompleto;
  String? telefone;
  String? instituicao;

  // Viagem programada pelo administrador para hoje (viagem_do_dia).
  ViagemDoDia? proximaViagem;
  bool carregandoViagem = true;
  bool erroViagem = false;

  // Enquete do dia: 'ida_volta', 'ida', 'volta' ou 'nao_vai'.
  // null = ainda não respondeu hoje.
  String? meuTrajeto;

  // Quantas pessoas escolheram cada opção hoje.
  Map<String, int> contagemPresenca = const {};

  Timer? timerEnquete;

  // Data (YYYY-MM-DD local) a que meuTrajeto se refere.
  String? dataConfirmacao;

  bool salvandoPresenca = false;

  // FINANCEIRO (Stripe, sincronizado pelo webhook)

  // Valor do plano no Stripe (price da "Mensalidade FretApp").
  static const valorPlanoCentavos = 20000;

  bool carregandoFinanceiro = true;
  String? erroFinanceiro;
  Map<String, dynamic>? assinatura;
  // public.mensalidades do passageiro (com os pagamentos de cada uma).
  List<Map<String, dynamic>> mensalidades = [];
  bool abrindoStripe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    carregarDados();
    tratarRetornoStripe();
    // Atualiza os números da enquete enquanto a tela está aberta.
    timerEnquete = Timer.periodic(
      const Duration(seconds: 30),
      (_) => carregarContagem(),
    );
  }

  /// Ao voltar do Checkout (web), o Stripe redireciona com ?pagamento=...
  void tratarRetornoStripe() {
    final retorno = Uri.base.queryParameters['pagamento'];
    if (retorno == null) {
      carregarFinanceiro();
      return;
    }

    paginaSelecionada = 1;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (retorno == 'sucesso') {
        aviso('Pagamento enviado! Atualizando sua assinatura...');
        await carregarFinanceiro();
        // O webhook pode levar alguns segundos para gravar.
        for (var i = 0; i < 4 && mounted && !assinaturaEmVigor; i++) {
          await Future.delayed(const Duration(seconds: 3));
          await carregarFinanceiro(silencioso: true);
        }
      } else {
        aviso('Pagamento cancelado.');
        await carregarFinanceiro();
      }
    });
  }

  String? get statusAssinatura => assinatura?['status'] as String?;

  bool get assinaturaEmVigor => const [
        'active',
        'trialing',
        'past_due',
        'unpaid',
      ].contains(statusAssinatura);

  Future<void> carregarFinanceiro({bool silencioso = false}) async {
    final user = usuario;
    if (user == null) return;

    if (!silencioso) {
      setState(() {
        carregandoFinanceiro = true;
        erroFinanceiro = null;
      });
    }

    try {
      final dadosAssinatura = await supabase
          .from('assinaturas_stripe')
          .select('status, periodo_fim, cancelar_no_fim')
          .eq('passageiro_id', user.id)
          .maybeSingle();

      final dadosMensalidades = await supabase
          .from('mensalidades')
          .select(
            'id, competencia, valor_centavos, vencimento, status, '
            'pagamentos(status, pago_em, provedor)',
          )
          .eq('passageiro_id', user.id)
          .order('competencia', ascending: false)
          .limit(12);

      if (!mounted) return;
      setState(() {
        assinatura = dadosAssinatura;
        mensalidades = List<Map<String, dynamic>>.from(dadosMensalidades);
        carregandoFinanceiro = false;
        erroFinanceiro = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar financeiro: $e');
      if (!mounted) return;
      setState(() {
        carregandoFinanceiro = false;
        erroFinanceiro = 'Não foi possível carregar seus pagamentos.';
      });
    }
  }

  /// Chama uma Edge Function que devolve {url} e abre a página do Stripe.
  Future<void> abrirStripe(String funcao) async {
    if (abrindoStripe) return;
    setState(() => abrindoStripe = true);

    try {
      final resposta = await supabase.functions.invoke(funcao);
      final url = (resposta.data as Map?)?['url'] as String?;
      if (url == null) throw Exception('Resposta sem URL');

      final abriu = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_self',
      );
      if (!abriu) throw Exception('Não abriu a URL');
    } on FunctionException catch (e) {
      debugPrint('Erro em $funcao: ${e.status} ${e.details}');
      final detalhes = e.details;
      aviso(
        detalhes is Map && detalhes['erro'] is String
            ? detalhes['erro'] as String
            : 'Não foi possível abrir o pagamento. Tente novamente.',
      );
    } catch (e) {
      debugPrint('Erro em $funcao: $e');
      aviso('Não foi possível abrir o pagamento. Tente novamente.');
    } finally {
      if (mounted) setState(() => abrindoStripe = false);
    }
  }

  String formatarValor(int? centavos) {
    if (centavos == null) return '—';
    final reais = (centavos ~/ 100).toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
    final resto = (centavos % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$resto';
  }

  String formatarData(dynamic iso) {
    if (iso is! String) return '—';
    final data = DateTime.tryParse(iso)?.toLocal();
    if (data == null) return '—';
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  (String, Color) rotuloStatusAssinatura() {
    switch (statusAssinatura) {
      case 'active':
      case 'trialing':
        return assinatura?['cancelar_no_fim'] == true
            ? ('Cancelamento agendado', Colors.orange)
            : ('Ativa', Colors.green);
      case 'past_due':
      case 'unpaid':
        return ('Pagamento pendente', Colors.orange);
      case 'incomplete':
        return ('Aguardando pagamento', Colors.orange);
      case 'canceled':
      case 'incomplete_expired':
        return ('Cancelada', Colors.red);
      default:
        return ('Sem assinatura', Colors.blueGrey);
    }
  }

  (String, Color) rotuloStatusMensalidade(String? status) {
    switch (status) {
      case 'paga':
        return ('Paga', Colors.green);
      case 'pendente':
        return ('Pendente', Colors.orange);
      case 'vencida':
        return ('Vencida', Colors.red);
      case 'cancelada':
        return ('Cancelada', Colors.blueGrey);
      default:
        return (status ?? '—', Colors.blueGrey);
    }
  }

  static const nomesMeses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  /// '2026-11-01' -> 'Novembro/2026' (coluna date, sem fuso).
  String formatarCompetencia(dynamic valor) {
    if (valor is! String || valor.length < 7) return '—';
    final ano = valor.substring(0, 4);
    final mes = int.tryParse(valor.substring(5, 7));
    if (mes == null || mes < 1 || mes > 12) return valor;
    return '${nomesMeses[mes - 1]}/$ano';
  }

  /// Coluna date 'YYYY-MM-DD' -> 'DD/MM/YYYY' sem converter fuso.
  String formatarDataSimples(dynamic valor) {
    if (valor is! String || valor.length < 10) return '—';
    return '${valor.substring(8, 10)}/${valor.substring(5, 7)}/${valor.substring(0, 4)}';
  }


  @override
  void dispose() {
    timerEnquete?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Se o app volta do segundo plano em outro dia, recarrega a confirmação
  // para não exibir a resposta de ontem como se fosse de hoje.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        dataConfirmacao != null &&
        dataConfirmacao != dataLocalHoje()) {
      carregarDados();
    }
  }

  /// Data local do passageiro no formato da coluna `date` (sem UTC).
  String dataLocalHoje() {
    final agora = DateTime.now();
    final mes = agora.month.toString().padLeft(2, '0');
    final dia = agora.day.toString().padLeft(2, '0');
    return '${agora.year}-$mes-$dia';
  }

  String? textoOuNulo(dynamic valor) {
    final texto = (valor as String?)?.trim();
    return (texto == null || texto.isEmpty) ? null : texto;
  }

  Future<void> carregarDados() async {
    final user = usuario;

    if (user == null) {
      setState(() {
        carregando = false;
        erroCarregamento = 'Sessão expirada. Entre novamente.';
      });
      return;
    }

    setState(() {
      carregando = true;
      erroCarregamento = null;
    });

    final hoje = dataLocalHoje();

    try {
      final perfil = await supabase
          .from('perfis')
          .select('id, nome_completo, telefone, instituicao, tipo')
          .eq('id', user.id)
          .maybeSingle();

      final confirmacao = await supabase
          .from('confirmacoes_presenca')
          .select('trajeto')
          .eq('passageiro_id', user.id)
          .eq('data', hoje)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        perfilExiste = perfil != null;
        nomeCompleto = textoOuNulo(perfil?['nome_completo']);
        telefone = textoOuNulo(perfil?['telefone']);
        instituicao = textoOuNulo(perfil?['instituicao']);

        meuTrajeto = confirmacao?['trajeto'] as String?;
        dataConfirmacao = hoje;

        carregando = false;
      });

      carregarContagem();
      carregarViagem();
    } catch (e) {
      debugPrint('Erro ao carregar dados do passageiro: $e');
      if (!mounted) return;
      setState(() {
        carregando = false;
        erroCarregamento =
            'Não foi possível carregar seus dados. Verifique a conexão.';
      });
    }
  }

  /// Atualiza uma única coluna do próprio perfil e devolve o valor
  /// gravado no banco. Lança exceção se nenhuma linha for atualizada.
  Future<String?> salvarCampoPerfil(String coluna, String valor) async {
    final user = usuario;
    if (user == null) throw Exception('Sessão expirada.');

    final resposta = await supabase
        .from('perfis')
        .update({coluna: valor})
        .eq('id', user.id)
        .select(coluna)
        .maybeSingle();

    // RLS bloqueando ou linha inexistente: o update afeta 0 linhas.
    if (resposta == null) {
      throw Exception('Perfil não encontrado ou sem permissão.');
    }

    return textoOuNulo(resposta[coluna]);
  }

  /// Viagem do dia; falha aqui não derruba o resto da tela.
  Future<void> carregarViagem() async {
    setState(() {
      carregandoViagem = true;
      erroViagem = false;
    });
    try {
      final viagem = await buscarViagemDoDia();
      if (!mounted) return;
      setState(() {
        proximaViagem = viagem;
        carregandoViagem = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar a viagem do dia: $e');
      if (!mounted) return;
      setState(() {
        carregandoViagem = false;
        erroViagem = true;
      });
    }
  }

  /// Busca quantas pessoas escolheram cada opção hoje (só números).
  Future<void> carregarContagem() async {
    if (usuario == null) return;

    // Virou o dia com a tela aberta: recarrega tudo (resposta começa vazia).
    if (dataConfirmacao != null && dataConfirmacao != dataLocalHoje()) {
      await carregarDados();
      return;
    }
    try {
      final linhas = await supabase.rpc(
        'contagem_presenca',
        params: {'p_data': dataLocalHoje()},
      );
      final dados = (linhas as List).isNotEmpty
          ? Map<String, dynamic>.from(linhas.first as Map)
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        contagemPresenca = {
          'ida_volta': (dados['ida_volta'] as int?) ?? 0,
          'ida': (dados['so_ida'] as int?) ?? 0,
          'volta': (dados['so_volta'] as int?) ?? 0,
          'nao_vai': (dados['nao_vai'] as int?) ?? 0,
        };
      });
    } catch (e) {
      // A enquete continua funcionando; só os números ficam desatualizados.
      debugPrint('Erro ao carregar contagem da enquete: $e');
    }
  }

  Future<void> marcarPresenca(String trajeto) async {
    final user = usuario;
    if (salvandoPresenca || user == null || trajeto == meuTrajeto) return;

    final hoje = dataLocalHoje();

    setState(() => salvandoPresenca = true);

    try {
      await supabase.from('confirmacoes_presenca').upsert(
        {
          'passageiro_id': user.id,
          'data': hoje,
          'trajeto': trajeto,
          'vai_comparecer': trajeto != 'nao_vai',
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'passageiro_id,data',
      );

      if (!mounted) return;
      setState(() {
        meuTrajeto = trajeto;
        dataConfirmacao = hoje;
      });
      await carregarContagem();
    } catch (e) {
      debugPrint('Erro ao salvar presença: $e');
      aviso('Não foi possível salvar sua resposta. Tente novamente.');
    } finally {
      if (mounted) setState(() => salvandoPresenca = false);
    }
  }

  final paginas = const [
    'Início',
    'Financeiro',
    'Meu perfil',
  ];

  void navegar(int index) {
    setState(() => paginaSelecionada = index);
  }

  Future<void> sair() async {
    await Supabase.instance.client.auth.signOut();
  }

  void aviso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  /// Abre o diálogo, valida, grava no Supabase e só então atualiza a tela.
  Future<void> editarCampo({
    required String titulo,
    required String coluna,
    required String? valorAtual,
    required String? Function(String) validar,
    required void Function(String?) aoSalvar,
  }) async {
    if (!perfilExiste) {
      aviso('Seu perfil ainda não foi criado. Fale com o administrador.');
      return;
    }

    final controller = TextEditingController(text: valorAtual ?? '');
    String? erro;
    bool salvando = false;

    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> confirmar() async {
            final valor = controller.text.trim();
            final mensagemErro = validar(valor);

            if (mensagemErro != null) {
              setDialogState(() => erro = mensagemErro);
              return;
            }

            setDialogState(() {
              erro = null;
              salvando = true;
            });

            try {
              final valorGravado = await salvarCampoPerfil(coluna, valor);
              aoSalvar(valorGravado);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            } catch (e) {
              debugPrint('Erro ao salvar $coluna: $e');
              setDialogState(() {
                salvando = false;
                erro = 'Não foi possível salvar. Tente novamente.';
              });
            }
          }

          return AlertDialog(
            title: Text('Editar $titulo'),
            content: TextField(
              controller: controller,
              autofocus: true,
              enabled: !salvando,
              onSubmitted: (_) => salvando ? null : confirmar(),
              decoration: InputDecoration(
                labelText: titulo,
                errorText: erro,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    salvando ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: salvando ? null : confirmar,
                child: salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();

    if (salvou == true) {
      aviso('Alteração salva com sucesso.');
    }
  }

  String? validarTelefone(String valor) {
    if (valor.isEmpty) return 'Informe um telefone.';
    if (!regexTelefone.hasMatch(valor)) {
      return 'Use de 8 a 20 caracteres: números, espaço, ( ) + . -';
    }
    return null;
  }

  String? validarInstituicao(String valor) {
    if (valor.isEmpty) return 'Informe a instituição.';
    if (valor.length > 120) return 'Máximo de 120 caracteres.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;

        return Scaffold(
          backgroundColor: fundo,

          appBar: desktop
              ? null
              : AppBar(
                  backgroundColor: Colors.white,
                  foregroundColor: azulEscuro,
                  elevation: 0,
                  title: const Text(
                    'FretApp',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () => aviso(
                        'Notificações em breve.',
                      ),
                      icon: const Icon(Icons.notifications_none),
                    ),
                    IconButton(
                      onPressed: sair,
                      icon: const Icon(Icons.logout),
                      tooltip: 'Sair',
                    ),
                  ],
                ),

          body: Row(
            children: [
              if (desktop) construirMenuLateral(),

              Expanded(
                child: Column(
                  children: [
                    if (desktop) construirCabecalho(),

                    Expanded(child: construirPagina()),
                  ],
                ),
              ),
            ],
          ),

          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: paginaSelecionada,
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFDBEAFE),
                  onDestinationSelected: navegar,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Início',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: 'Financeiro',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Perfil',
                    ),
                  ],
                ),
        );
      },
    );
  }

  // MENU LATERAL

  Widget construirMenuLateral() {
    return Container(
      width: 245,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 28),

          const Icon(
            Icons.directions_bus_filled,
            size: 38,
            color: azulEscuro,
          ),

          const SizedBox(height: 8),

          const Text(
            'FretApp',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: azulEscuro,
            ),
          ),

          const Text(
            'ÁREA DO PASSAGEIRO',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: Colors.blueGrey,
            ),
          ),

          const SizedBox(height: 35),
          const Divider(height: 1),
          const SizedBox(height: 18),

          for (int i = 0; i < paginas.length; i++)
            construirItemMenu(i),

          const Spacer(),
          const Divider(height: 1),

          // ÚNICO BOTÃO DE SAIR DA CONTA
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDBEAFE),
              child: Icon(Icons.person, color: azul),
            ),
            title: const Text(
              'Passageiro',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Minha conta',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.logout, size: 19),
            onTap: sair,
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget construirItemMenu(int index) {
    final icones = [
      Icons.dashboard_outlined,
      Icons.account_balance_wallet_outlined,
      Icons.person_outline,
    ];

    final iconesSelecionados = [
      Icons.dashboard,
      Icons.account_balance_wallet,
      Icons.person,
    ];

    final selecionado = paginaSelecionada == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: ListTile(
        selected: selecionado,
        selectedTileColor: const Color(0xFFDBEAFE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Icon(
          selecionado
              ? iconesSelecionados[index]
              : icones[index],
          color: selecionado ? azul : Colors.blueGrey,
        ),
        title: Text(
          paginas[index],
          style: TextStyle(
            color: selecionado ? azulEscuro : Colors.blueGrey,
            fontWeight:
                selecionado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => navegar(index),
      ),
    );
  }

  // CABEÇALHO

  Widget construirCabecalho() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Text(
            paginas[paginaSelecionada],
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: azulEscuro,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => aviso('Notificações em breve.'),
            icon: const Icon(
              Icons.notifications_none,
              color: azulEscuro,
            ),
          ),
        ],
      ),
    );
  }

  // PÁGINAS

  Widget construirPagina() {
    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (erroCarregamento != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 42, color: Colors.blueGrey),
              const SizedBox(height: 12),
              Text(
                erroCarregamento!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: carregarDados,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: FilledButton.styleFrom(backgroundColor: azul),
              ),
            ],
          ),
        ),
      );
    }

    switch (paginaSelecionada) {
      case 0:
        return construirInicio();
      case 1:
        return construirFinanceiro();
      case 2:
        return construirPerfil();
      default:
        return construirInicio();
    }
  }

  // INÍCIO

  Widget construirInicio() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        tituloPagina(
          nomeCompleto != null
              ? 'Olá, ${nomeCompleto!.split(' ').first}!'
              : 'Olá!',
          'Confira sua programação para hoje.',
        ),

        const SizedBox(height: 28),

        construirConfirmacaoPresenca(),

        const SizedBox(height: 28),

        tituloSecao('Sua próxima viagem'),

        const SizedBox(height: 12),

        construirCartaoViagem(),

        const SizedBox(height: 28),

        tituloSecao('Comunicação'),

        const SizedBox(height: 12),

        construirComunicado(),
      ],
    );
  }

  // ENQUETE DE PRESENÇA (estilo enquete do WhatsApp)

  static const opcoesTrajeto = [
    ('ida_volta', 'Ida e volta', Icons.sync_alt),
    ('ida', 'Somente ida', Icons.arrow_forward),
    ('volta', 'Somente volta', Icons.arrow_back),
    ('nao_vai', 'Não vou', Icons.block),
  ];

  Widget construirConfirmacaoPresenca() {
    final total = contagemPresenca.values.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cartaoDecoracao().copyWith(
        border: Border.all(color: azul.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.how_to_vote_outlined, color: azul),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Você vai para a faculdade hoje?',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: azulEscuro,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Escolha uma opção. Você pode mudar durante o dia.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: carregarContagem,
                icon: const Icon(Icons.refresh, color: Colors.blueGrey),
              ),
            ],
          ),

          const SizedBox(height: 22),

          for (final (valor, rotulo, icone) in opcoesTrajeto) ...[
            construirOpcaoEnquete(
              valor: valor,
              rotulo: rotulo,
              icone: icone,
              quantidade: contagemPresenca[valor] ?? 0,
              total: total,
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 4),

          Row(
            children: [
              const Icon(Icons.people_outline, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(
                total == 1 ? '1 resposta hoje' : '$total respostas hoje',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (salvandoPresenca)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (meuTrajeto == null)
                const Text(
                  'Você ainda não respondeu',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget construirOpcaoEnquete({
    required String valor,
    required String rotulo,
    required IconData icone,
    required int quantidade,
    required int total,
  }) {
    final selecionada = meuTrajeto == valor;
    final cor = valor == 'nao_vai' ? Colors.red.shade400 : azul;
    final fracao = total == 0 ? 0.0 : quantidade / total;

    return Material(
      color: selecionada ? cor.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: salvandoPresenca ? null : () => marcarPresenca(valor),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selecionada ? cor : const Color(0xFFE2E8F0),
              width: selecionada ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    selecionada
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selecionada ? cor : Colors.blueGrey.shade300,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Icon(icone, size: 20, color: cor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rotulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            selecionada ? FontWeight.bold : FontWeight.w600,
                        color: azulEscuro,
                      ),
                    ),
                  ),
                  Text(
                    '$quantidade',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selecionada ? cor : azulEscuro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fracao),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, valorBarra, _) =>
                        LinearProgressIndicator(
                      value: valorBarra,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFEFF3F8),
                      valueColor: AlwaysStoppedAnimation(
                        selecionada ? cor : cor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget construirCartaoViagem() {
    final viagem = proximaViagem;

    // Sem dados da viagem: mostra o motivo, mas o mapa do ônibus continua
    // na tela (o ônibus ao vivo não depende da viagem programada).
    if (viagem == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: cartaoDecoracao(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (carregandoViagem)
              const EstadoCarregando(mensagem: 'Buscando a viagem de hoje…')
            else if (erroViagem)
              EstadoErro(
                titulo: 'Não foi possível carregar a viagem',
                aoTentarDeNovo: carregarViagem,
              )
            else
              const EstadoVazio(
                icone: Icons.event_busy_outlined,
                titulo: 'Nenhuma viagem programada para hoje',
              ),
            const SizedBox(height: 16),
            const MapaOnibusAoVivo(),
          ],
        ),
      );
    }

    final embarque = viagem.pontos.isNotEmpty ? viagem.pontos.first : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cartaoDecoracao(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'HORÁRIO DE EMBARQUE',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              ChipStatus.viagem(viagem.status),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            embarque?.horario ?? viagem.horarioSaida,
            style: const TextStyle(
              color: azul,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (viagem.nomeRota != null)
            Text(
              [
                viagem.nomeRota!,
                if (viagem.distanciaKm != null)
                  '${viagem.distanciaKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                if (viagem.duracaoMin != null) '~${viagem.duracaoMin} min',
              ].join(' · '),
              style: const TextStyle(color: Colors.blueGrey),
            ),

          const Divider(height: 30),

          linhaLocal(
            Icons.trip_origin,
            Colors.green,
            'Ponto de embarque',
            embarque?.nome ?? viagem.origem,
          ),

          const SizedBox(height: 20),

          linhaLocal(
            Icons.location_on,
            Colors.red,
            'Destino',
            viagem.destino,
          ),

          const SizedBox(height: 24),

          MapaOnibusAoVivo(
            trajeto: viagem.trajeto,
            pontos: viagem.pontos,
          ),
        ],
      ),
    );
  }

  Widget construirComunicado() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cartaoDecoracao(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.campaign, color: azul),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administrador',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Comunicado recente',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            'Bem-vindo ao FretApp!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Aqui você receberá avisos sobre horários, '
            'alterações de rotas e informações importantes '
            'enviadas pela administração.',
            style: TextStyle(
              color: Colors.blueGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // FINANCEIRO

  Widget construirFinanceiro() {
    if (carregandoFinanceiro) {
      return const Center(child: CircularProgressIndicator());
    }

    final (rotulo, corStatus) = rotuloStatusAssinatura();
    final valor = mensalidades.isNotEmpty
        ? (mensalidades.first['valor_centavos'] as int?) ?? valorPlanoCentavos
        : valorPlanoCentavos;
    final cancelaNoFim = assinatura?['cancelar_no_fim'] == true;

    return RefreshIndicator(
      onRefresh: carregarFinanceiro,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          tituloPagina(
            'Financeiro',
            'Consulte suas mensalidades e pagamentos.',
          ),

          const SizedBox(height: 25),

          if (erroFinanceiro != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(erroFinanceiro!)),
                  TextButton(
                    onPressed: carregarFinanceiro,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: azulEscuro,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MENSALIDADE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  formatarValor(valor),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cobrança mensal automática',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          tituloSecao('Situação financeira'),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: cartaoDecoracao(),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_outlined, color: corStatus),
                  title: const Text('Assinatura'),
                  trailing: etiqueta(rotulo, corStatus),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: azul),
                  title: Text(
                    cancelaNoFim ? 'Assinatura termina em' : 'Próximo vencimento',
                  ),
                  subtitle: Text(
                    assinaturaEmVigor
                        ? formatarData(assinatura?['periodo_fim'])
                        : 'Assine para ativar a cobrança mensal',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: assinaturaEmVigor
                ? OutlinedButton.icon(
                    onPressed: abrindoStripe
                        ? null
                        : () => abrirStripe('portal-cliente'),
                    icon: const Icon(Icons.credit_card),
                    label: Text(
                      statusAssinatura == 'past_due' ||
                              statusAssinatura == 'unpaid'
                          ? 'Regularizar pagamento'
                          : 'Gerenciar pagamento',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: abrindoStripe
                        ? null
                        : () => abrirStripe('criar-checkout'),
                    icon: abrindoStripe
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_outline),
                    label: const Text('Assinar mensalidade'),
                    style: FilledButton.styleFrom(
                      backgroundColor: azul,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Pagamento seguro processado pelo Stripe (cartão ou PIX).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),

          const SizedBox(height: 24),

          tituloSecao('Minhas mensalidades'),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: cartaoDecoracao(),
            child: mensalidades.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 38,
                          color: Colors.blueGrey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Nenhuma mensalidade registrada.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < mensalidades.length; i++) ...[
                        if (i > 0) const Divider(),
                        construirItemMensalidade(mensalidades[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget construirItemMensalidade(Map<String, dynamic> mensalidade) {
    final status = mensalidade['status'] as String?;
    final (rotulo, cor) = rotuloStatusMensalidade(status);

    final pagos = List<Map<String, dynamic>>.from(
      (mensalidade['pagamentos'] as List?) ?? const [],
    ).where((p) => p['status'] == 'aprovado' && p['pago_em'] != null);

    final detalhe = status == 'paga' && pagos.isNotEmpty
        ? 'Pago em ${formatarData(pagos.first['pago_em'])}'
        : 'Vence em ${formatarDataSimples(mensalidade['vencimento'])}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.receipt_long_outlined, color: cor),
      title: Text(
        '${formatarCompetencia(mensalidade['competencia'])} · '
        '${formatarValor(mensalidade['valor_centavos'] as int?)}',
      ),
      subtitle: Text(detalhe),
      trailing: etiqueta(rotulo, cor),
    );
  }

  // PERFIL

  Widget construirPerfil() {
    final email = usuario?.email ?? 'E-mail não disponível';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        tituloPagina(
          'Meu perfil',
          'Consulte e atualize suas informações pessoais.',
        ),

        const SizedBox(height: 28),

        if (!perfilExiste) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seu perfil ainda não foi criado no sistema. '
                    'Fale com o administrador para liberar a edição.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        Container(
          padding: const EdgeInsets.all(24),
          decoration: cartaoDecoracao(),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(
                  Icons.person,
                  size: 46,
                  color: azul,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                nomeCompleto ?? 'Nome não informado',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: azulEscuro,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Passageiro',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        tituloSecao('Dados pessoais'),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: cartaoDecoracao(),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: azul),
                title: const Text('Nome'),
                subtitle: Text(nomeCompleto ?? 'Não informado'),
              ),

              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined, color: azul),
                title: const Text('E-mail'),
                subtitle: Text(email),
              ),

              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined, color: azul),
                title: const Text('Telefone'),
                subtitle: Text(telefone ?? 'Não informado'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    editarCampo(
                      titulo: 'telefone',
                      coluna: 'telefone',
                      valorAtual: telefone,
                      validar: validarTelefone,
                      aoSalvar: (valor) {
                        setState(() => telefone = valor);
                      },
                    );
                  },
                ),
              ),

              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined, color: azul),
                title: const Text('Instituição'),
                subtitle: Text(instituicao ?? 'Não informada'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    editarCampo(
                      titulo: 'instituição',
                      coluna: 'instituicao',
                      valorAtual: instituicao,
                      validar: validarInstituicao,
                      aoSalvar: (valor) {
                        setState(() => instituicao = valor);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }

  // COMPONENTES REUTILIZÁVEIS

  Widget tituloPagina(String titulo, String descricao) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: azulEscuro,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          descricao,
          style: const TextStyle(color: Colors.blueGrey),
        ),
      ],
    );
  }

  Widget tituloSecao(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: azulEscuro,
      ),
    );
  }

  Widget etiqueta(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget linhaLocal(
    IconData icone,
    Color cor,
    String titulo,
    String descricao,
  ) {
    return Row(
      children: [
        Icon(icone, color: cor, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12,
                ),
              ),
              Text(
                descricao,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration cartaoDecoracao() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFE2E8F0),
      ),
    );
  }
}