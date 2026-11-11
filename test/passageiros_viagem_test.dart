import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/models/passageiro_viagem.dart';
import 'package:fretapp/viewmodels/motorista_viewmodel.dart';

void main() {
  test('a lista inicial corresponde aos quatro embarques demonstrativos', () {
    final modelo = MotoristaViewModel();
    addTearDown(modelo.dispose);

    final lista = modelo.passageirosFiltrados;
    expect(
      lista.map((p) => (p.nome, p.pontoEmbarque, p.embarcou)),
      unorderedEquals([
        ('Ana Souza', 'Praça Central', true),
        ('Carlos Lima', 'Terminal Rodoviário', true),
        ('Beatriz Alves', 'Avenida Brasil', false),
        ('João Pedro', 'Praça Central', false),
      ]),
    );
    expect(
      (modelo.totalPassageiros, modelo.embarcados, modelo.pendentes),
      (4, 2, 2),
    );
  });

  test('buscar não altera o total da viagem e embarques são reversíveis', () {
    final modelo = MotoristaViewModel();
    addTearDown(modelo.dispose);

    modelo.pesquisar('  JOAO  ');
    final joao = modelo.passageirosFiltrados.single;
    expect(joao.nome, 'João Pedro');
    expect(
      (modelo.totalPassageiros, modelo.embarcados, modelo.pendentes),
      (4, 2, 2),
    );
    modelo.definirEmbarque(joao.id, true);
    modelo.definirEmbarque(joao.id, true);
    expect(modelo.passageirosFiltrados.single.embarcou, isTrue);
    expect(
      (modelo.totalPassageiros, modelo.embarcados, modelo.pendentes),
      (4, 3, 1),
    );

    modelo.pesquisar('ausente');
    expect(modelo.passageirosFiltrados, isEmpty);
    expect(
      (modelo.totalPassageiros, modelo.embarcados, modelo.pendentes),
      (4, 3, 1),
    );
    modelo.pesquisar('edr');
    expect(modelo.passageirosFiltrados.single.id, joao.id);
    modelo.definirEmbarque(joao.id, false);
    modelo.definirEmbarque(joao.id, false);
    modelo.pesquisar('');
    expect(modelo.passageirosFiltrados.length, 4);
    expect(
      modelo.passageirosFiltrados.singleWhere((p) => p.id == joao.id).embarcou,
      isFalse,
    );
    expect(
      (modelo.totalPassageiros, modelo.embarcados, modelo.pendentes),
      (4, 2, 2),
    );
  });

  test('seleciona e altera apenas os embarques associados à viagem', () {
    const passageiros = [
      PassageiroViagem(
        id: 'ana',
        viagemId: 'ida',
        nome: 'Ana Souza',
        pontoEmbarque: 'Praça Central',
        embarcou: false,
      ),
      PassageiroViagem(
        id: 'ana',
        viagemId: 'volta',
        nome: 'Ana Souza',
        pontoEmbarque: 'Faculdade',
        embarcou: false,
      ),
      PassageiroViagem(
        id: 'outro',
        viagemId: 'volta',
        nome: 'Carlos Lima',
        pontoEmbarque: 'Faculdade',
        embarcou: false,
      ),
    ];
    final ida = MotoristaViewModel(viagemId: 'ida', passageiros: passageiros);
    final volta = MotoristaViewModel(
      viagemId: 'volta',
      passageiros: passageiros,
    );
    addTearDown(ida.dispose);
    addTearDown(volta.dispose);

    expect(ida.totalPassageiros, 1);
    expect(ida.passageirosFiltrados.single.pontoEmbarque, 'Praça Central');
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
