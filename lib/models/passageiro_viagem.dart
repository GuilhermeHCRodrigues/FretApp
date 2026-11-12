/// Embarque de uma pessoa em uma viagem específica.
class PassageiroViagem {
  const PassageiroViagem({
    required this.id,
    required this.viagemId,
    required this.nome,
    required this.pontoEmbarque,
    this.embarcou = false,
  });

  final String id;
  final String viagemId;
  final String nome;
  final String pontoEmbarque;
  final bool embarcou;

  PassageiroViagem comEmbarque(bool confirmado) => PassageiroViagem(
    id: id,
    viagemId: viagemId,
    nome: nome,
    pontoEmbarque: pontoEmbarque,
    embarcou: confirmado,
  );
}
