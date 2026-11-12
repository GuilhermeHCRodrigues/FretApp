-- Estrutura do gerenciamento administrativo de viagens do FretApp.
-- Execute no SQL Editor do Supabase antes de abrir a tela Viagens.

create table if not exists public.viagens (
  id uuid primary key default gen_random_uuid(),
  rota_id uuid not null references public.rotas(id) on delete restrict,
  motorista_id uuid references public.motoristas(id) on delete set null,
  veiculo_id uuid references public.veiculos(id) on delete set null,
  data_viagem date not null,
  horario_saida time not null,
  status text not null default 'agendada'
    check (status in ('agendada', 'em_andamento', 'finalizada', 'cancelada')),
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.viagem_passageiros (
  id uuid primary key default gen_random_uuid(),
  viagem_id uuid not null references public.viagens(id) on delete cascade,
  passageiro_id uuid not null references public.passageiros(id) on delete restrict,
  ponto_embarque_id uuid references public.pontos_rota(id) on delete set null,
  embarcou boolean not null default false,
  horario_embarque timestamptz,
  created_at timestamptz not null default now(),
  constraint viagem_passageiros_unicos unique (viagem_id, passageiro_id)
);

create index if not exists viagens_data_status_idx
  on public.viagens (data_viagem, status);
create index if not exists viagens_rota_idx
  on public.viagens (rota_id);
create index if not exists viagens_motorista_idx
  on public.viagens (motorista_id);
create index if not exists viagens_veiculo_idx
  on public.viagens (veiculo_id);
create index if not exists viagem_passageiros_viagem_idx
  on public.viagem_passageiros (viagem_id);
create index if not exists viagem_passageiros_passageiro_idx
  on public.viagem_passageiros (passageiro_id);

alter table public.viagens enable row level security;
alter table public.viagem_passageiros enable row level security;

drop policy if exists "Administradores gerenciam viagens" on public.viagens;
create policy "Administradores gerenciam viagens"
on public.viagens for all to authenticated
using (public.fretapp_usuario_e_administrador())
with check (public.fretapp_usuario_e_administrador());

drop policy if exists "Administradores gerenciam passageiros das viagens"
on public.viagem_passageiros;
create policy "Administradores gerenciam passageiros das viagens"
on public.viagem_passageiros for all to authenticated
using (public.fretapp_usuario_e_administrador())
with check (public.fretapp_usuario_e_administrador());

grant select, insert, update, delete on public.viagens to authenticated;
grant select, insert, update, delete on public.viagem_passageiros to authenticated;
