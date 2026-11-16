# 🚌 FretApp — Gestão de Transporte Universitário

Sistema de gerenciamento de transporte fretado universitário, desenvolvido para centralizar a administração de passageiros, motoristas, veículos, rotas, viagens e mensalidades, oferecendo também acompanhamento da localização dos ônibus em tempo real.

## 📌 Sobre o projeto

O **FretApp** é uma aplicação desenvolvida com o objetivo de modernizar e facilitar a gestão do transporte fretado universitário.

A plataforma conecta administradores, motoristas e passageiros em um único ambiente, proporcionando maior organização operacional, comunicação e transparência no acompanhamento das viagens.

Por meio do sistema, é possível gerenciar os cadastros, organizar viagens, acompanhar a localização dos ônibus e controlar as informações financeiras relacionadas ao serviço.

### 🎯 Objetivos

- Centralizar o gerenciamento do transporte universitário.
- Facilitar a administração de passageiros, motoristas e veículos.
- Organizar rotas e viagens programadas.
- Permitir o acompanhamento dos ônibus em tempo real.
- Disponibilizar informações financeiras e controle de mensalidades.
- Melhorar a comunicação entre os participantes do transporte.

## ⚙️ Funcionalidades

O sistema possui três áreas principais, de acordo com o perfil de acesso.

### 👨‍💼 Administrador

- Dashboard administrativo.
- Cadastro e gerenciamento de passageiros.
- Cadastro e gerenciamento de motoristas.
- Gerenciamento de veículos.
- Cadastro e gerenciamento de rotas.
- Planejamento e gerenciamento de viagens.
- Controle financeiro e mensalidades.
- Gerenciamento de assinaturas.
- Envio e gerenciamento de mensagens e avisos.
- Gerenciamento de acessos dos usuários.

### 🚍 Motorista

- Visualização das viagens programadas.
- Consulta aos passageiros da viagem.
- Visualização dos pontos e trajetos.
- Compartilhamento da localização via GPS.
- Atualização do status da viagem.
- Acompanhamento dos passageiros confirmados.
- Acesso às informações financeiras e mensagens.

### 🎓 Passageiro

- Acesso às informações da viagem.
- Visualização do trajeto programado.
- Acompanhamento da localização do ônibus em tempo real.
- Consulta de informações relacionadas ao transporte.

## 🛠️ Tecnologias utilizadas

| Tecnologia | Aplicação no projeto |
|---|---|
| Flutter | Desenvolvimento da interface e aplicação multiplataforma. |
| Dart | Linguagem de programação principal. |
| Supabase | Backend, autenticação e comunicação com o banco de dados. |
| PostgreSQL | Banco de dados relacional. |
| Supabase Realtime | Atualização de informações em tempo real. |
| Supabase Edge Functions | Execução de operações no backend. |
| Stripe | Gerenciamento de assinaturas e cobranças. |
| Geolocator | Acesso à localização GPS do motorista. |
| Flutter Map | Exibição de mapas e trajetos. |
| OpenStreetMap | Fornecimento de dados cartográficos. |
| Latlong2 | Manipulação de coordenadas geográficas. |

## 🏗️ Arquitetura do projeto

O FretApp utiliza uma organização inspirada no padrão arquitetural **MVVM (Model-View-ViewModel)**, com separação de responsabilidades entre interface, lógica de apresentação, serviços e estruturas de dados.

### Estrutura de diretórios

```text
FretApp/
│
├── lib/
│   ├── main.dart
│   │
│   ├── models/
│   │   └── Modelos e estruturas de dados
│   │
│   ├── services/
│   │   └── Serviços e integrações externas
│   │
│   ├── viewmodels/
│   │   └── Gerenciamento de estados e lógica
│   │
│   ├── views/
│   │   └── Telas e componentes da aplicação
│   │
│   └── tema/
│       └── Cores, temas e estilos visuais
│
├── supabase/
│   ├── functions/
│   │   └── Funções executadas no backend
│   │
│   └── migrations/
│       └── Scripts de criação e atualização do banco
│
├── test/
│   └── Testes automatizados
│
├── android/
├── ios/
├── web/
├── linux/
├── macos/
├── windows/
│
├── pubspec.yaml
└── README.md
```

### Responsabilidade das camadas

- **Models:** representam as estruturas de dados utilizadas pela aplicação.
- **Views:** apresentam as interfaces e recebem as interações dos usuários.
- **ViewModels:** gerenciam estados e lógica de apresentação.
- **Services:** concentram operações de comunicação com serviços externos.
- **Tema:** centraliza a identidade visual e a padronização dos componentes.
- **Supabase:** contém as funções de backend e as migrações do banco de dados.

## 🚀 Como executar o projeto

### 1. Pré-requisitos

Antes de executar o projeto, é necessário possuir:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado.
- [Dart SDK](https://dart.dev/get-dart) compatível com a versão especificada no `pubspec.yaml`.
- [Git](https://git-scm.com/downloads).
- Um editor de código, como [Visual Studio Code](https://code.visualstudio.com/) ou Android Studio.
- Acesso a um projeto configurado no Supabase.

Para verificar a instalação do Flutter, execute:

```bash
flutter doctor
```

### 2. Clonar o repositório

```bash
git clone https://github.com/GuilhermeHCRodrigues/FretApp.git
```

Entre no diretório:

```bash
cd FretApp
```

### 3. Instalar as dependências

Execute:

```bash
flutter pub get
```

Esse comando instala as dependências definidas no arquivo `pubspec.yaml`.

### 4. Configurar o Supabase

O projeto utiliza o Supabase como backend.

Para executar a aplicação, é necessário configurar uma chave pública válida do Supabase.

No arquivo `lib/main.dart`, a aplicação recebe essa chave por meio da variável de compilação:

```dart
const chavePublica = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
```

Execute a aplicação informando a chave:

```bash
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA
```

Substitua `SUA_CHAVE_PUBLICA` pela chave pública correspondente ao projeto Supabase.

A URL do projeto Supabase está configurada na inicialização da aplicação.

**Importante:** nunca disponibilize chaves secretas do Supabase ou do Stripe no código do aplicativo.

### 5. Configuração do backend

O diretório `supabase/` contém as migrations SQL e as Edge Functions necessárias ao funcionamento das funcionalidades integradas.

Para configurar o backend em um ambiente próprio:

1. Crie um projeto no Supabase.
2. Configure o Supabase CLI.
3. Vincule o projeto utilizando `supabase link`.
4. Aplique as migrations utilizando `supabase db push`.
5. Configure os secrets necessários às Edge Functions.
6. Publique as funções utilizando `supabase functions deploy`.

As funções relacionadas ao Stripe também exigem credenciais e configuração de webhook no ambiente do servidor.

A configuração completa do ambiente backend é necessária para utilizar funcionalidades como autenticação, gerenciamento de acessos, financeiro e sincronização de pagamentos.

### 6. Executar a aplicação

Para iniciar o aplicativo:

```bash
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA
```

Para executar no navegador Chrome:

```bash
flutter run -d chrome --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA
```

## 🗺️ Rastreamento em tempo real

Uma das principais funcionalidades do FretApp é o acompanhamento da localização dos ônibus.

O funcionamento ocorre por meio da integração entre Geolocator, Supabase Realtime e Flutter Map.

**Fluxo de funcionamento:**

1. O motorista autoriza o acesso à localização do dispositivo.
2. O Geolocator obtém as coordenadas geográficas.
3. As informações são enviadas ao Supabase.
4. O Supabase Realtime disponibiliza as atualizações.
5. O passageiro visualiza a posição atualizada do ônibus no mapa.

O sistema utiliza latitude e longitude para representar a posição do veículo e permite acompanhar o deslocamento durante a viagem.

O compartilhamento é realizado pelo motorista, enquanto o passageiro possui acesso somente à visualização da localização.

## 💳 Integração financeira

O sistema possui integração com o Stripe para gerenciamento de mensalidades e assinaturas.

A comunicação é realizada por meio de Supabase Edge Functions, responsáveis pelas operações no backend.

Também foi implementado um mecanismo de webhook para receber notificações de eventos financeiros e sincronizar as informações de pagamentos e assinaturas com o banco de dados.

## 🧪 Testes

O projeto possui testes automatizados na pasta `test/`, utilizando o pacote `flutter_test`.

Para executar os testes, utilize:

```bash
flutter test
```

Os testes contemplam funcionalidades como:

- Autenticação e controle de acesso.
- Dashboard administrativo.
- Gerenciamento financeiro.
- Área do motorista.
- Visualização dos passageiros da viagem.
- Acompanhamento do ônibus.

## 📸 Capturas de tela

As capturas de tela abaixo apresentam as principais interfaces do FretApp.

> Adicione as imagens na pasta `docs/screenshots/` do repositório e utilize os nomes indicados nos exemplos.

### Login

![Tela de login]([docs/screenshots/login.png](https://github.com/GuilhermeHCRodrigues/FretApp/blob/main/docs/screenshots/Tela%20de%20login.png))

### Dashboard administrativo

![Dashboard administrativo]([docs/screenshots/dashboard.png](https://github.com/GuilhermeHCRodrigues/FretApp/blob/main/docs/screenshots/Dashboard%20administrativo.png))

### Gerenciamento de passageiros

![Gerenciamento de passageiros]([docs/screenshots/passageiros.png](https://github.com/GuilhermeHCRodrigues/FretApp/blob/main/docs/screenshots/Gerenciamento%20de%20passageiros.png))

### Área do motorista

![Área do motorista]([docs/screenshots/motorista.png](https://github.com/GuilhermeHCRodrigues/FretApp/blob/main/docs/screenshots/%C3%81rea%20do%20motorista.png))

### Acompanhamento do ônibus

![Acompanhamento do ônibus]([docs/screenshots/mapa.png](https://github.com/GuilhermeHCRodrigues/FretApp/blob/main/docs/screenshots/Acompanhamento%20do%20%C3%B4nibus.png))

### Gerenciamento financeiro

![Gerenciamento financeiro]([docs/screenshots/financeiro.png](https://github.com/GuilhermeHCRodrigues/FretApp/blob/main/docs/screenshots/Gerenciamento%20financeiro.png))

## 👥 Equipe de desenvolvimento

Projeto desenvolvido em grupo como parte de uma atividade acadêmica.

**Integrantes:**

- Guilherme Henrique Costa Rodrigues
- João Guilherme Silva Domingos
- Luiz Eduardo Vieira Lopes
- Hugo Pereira Malaquias

## 🎓 Contexto acadêmico

Projeto desenvolvido no contexto acadêmico, com o propósito de aplicar conhecimentos de Engenharia de Software, desenvolvimento de aplicações multiplataforma, integração com banco de dados, arquitetura de software e comunicação em tempo real.

---

**FretApp — Conectando pessoas e facilitando o transporte universitário.**
