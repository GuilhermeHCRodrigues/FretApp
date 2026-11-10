-- Cria o cadastro administrativo de passageiros do FretApp.
-- Execute no SQL Editor do Supabase antes de usar a tela de Passageiros.
-- CPF, telefones e CEP são armazenados somente com números.

create table if not exists public.passageiros (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(btrim(nome)) >= 3),
  cpf varchar(11) not null unique check (cpf ~ '^[0-9]{11}$'),
  telefone varchar(11) not null check (telefone ~ '^[0-9]{10,11}$'),
  email text,
  data_nascimento date,
  cep varchar(8) check (cep is null or cep ~ '^[0-9]{8}$'),
  logradouro text,
  numero text,
  complemento text,
  bairro text,
  cidade text,
  uf varchar(2) check (uf is null or uf ~ '^[A-Z]{2}$'),
  nome_responsavel text,
  telefone_responsavel varchar(11)
    check (
      telefone_responsavel is null
      or telefone_responsavel ~ '^[0-9]{10,11}$'
    ),
  observacoes text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint passageiros_email_valido
    check (
      email is null
      or email ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
    )
);

alter table public.passageiros enable row level security;

drop policy if exists "Administradores gerenciam passageiros"
  on public.passageiros;

create policy "Administradores gerenciam passageiros"
  on public.passageiros
  for all
  to authenticated
  using (public.fretapp_usuario_e_administrador())
  with check (public.fretapp_usuario_e_administrador());

grant select, insert, update, delete on public.passageiros to authenticated;
