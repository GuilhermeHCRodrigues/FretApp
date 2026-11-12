/// Embarque de uma pessoa em uma viagem específica.
class PassageiroViagem {
  const PassageiroViagem({
    required this.id,
    required this.viagemId,
    required this.nome,
    this.pontoEmbarque,
    this.trajeto,
    this.embarcou = false,
  });

  final String id;
  final String viagemId;
  final String nome;
  final String? pontoEmbarque;

  /// Resposta da enquete do dia (`confirmacoes_presenca.trajeto`).
  final String? trajeto;
  final bool embarcou;

  PassageiroViagem comEmbarque(bool confirmado) => PassageiroViagem(
    id: id,
    viagemId: viagemId,
    nome: nome,
    pontoEmbarque: pontoEmbarque,
    trajeto: trajeto,
    embarcou: confirmado,
  );
}
