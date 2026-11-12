import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/models/passageiro_viagem.dart';
import 'package:fretapp/viewmodels/motorista_viewmodel.dart';

const _passageiros = [
  PassageiroViagem(id: 'ana', viagemId: 'v', nome: 'Ana Exemplo'),
  PassageiroViagem(id: 'bruno', viagemId: 'v', nome: 'Bruno Exemplo'),
  PassageiroViagem(id: 'joao', viagemId: 'v', nome: 'João Exemplo'),
];

void main() {
  test('buscar não altera o total da viagem e embarques são reversíveis', () {
    final modelo = MotoristaViewModel(viagemId: 'v', passageiros: _passageiros);
    addTearDown(modelo.dispose);

    modelo.pesquisar('  JOAO  ');
    final joao = modelo.passageirosFiltrados.single;
    expect(joao.nome, 'João Exemplo');
    modelo
      ..definirEmbarque(joao.id, true)
      ..definirEmbarque(joao.id, true);
    expect(
      (modelo.totalPassageiros, modelo.embarcados, modelo.pendentes),
      (3, 1, 2),
    );

    modelo.pesquisar('ausente');
    expect(modelo.passageirosFiltrados, isEmpty);
    expect(modelo.totalPassageiros, 3);

    modelo
      ..definirEmbarque(joao.id, false)
      ..pesquisar('');
    expect(modelo.passageirosFiltrados.length, 3);
    expect(modelo.embarcados, 0);
  });

  test('seleciona e altera apenas os embarques associados à viagem', () {
    const passageiros = [
      PassageiroViagem(id: 'ana', viagemId: 'ida', nome: 'Ana Exemplo'),
      PassageiroViagem(id: 'ana', viagemId: 'volta', nome: 'Ana Exemplo'),
      PassageiroViagem(id: 'outro', viagemId: 'volta', nome: 'Bruno Exemplo'),
    ];
    final ida = MotoristaViewModel(viagemId: 'ida', passageiros: passageiros);
    final volta = MotoristaViewModel(
      viagemId: 'volta',
      passageiros: passageiros,
    );
    addTearDown(ida.dispose);
    addTearDown(volta.dispose);

    expect(ida.totalPassageiros, 1);
    ida.definirEmbarque('outro', true);
    expect(ida.embarcados, 0);
    ida.definirEmbarque('ana', true);
    expect((ida.embarcados, ida.pendentes), (1, 0));
    expect(
      (volta.totalPassageiros, volta.embarcados, volta.pendentes),
      (2, 0, 2),
    );
  });
}
