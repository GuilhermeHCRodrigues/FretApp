-- Cadastro de rotas e pontos de parada do FretApp.
-- Execute este arquivo no SQL Editor do Supabase antes de abrir a tela Rotas.

create table if not exists public.rotas (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(btrim(nome)) >= 3),
  origem text not null,
  destino text not null,
  horario_saida time,
  dias_semana text[] not null default '{}',
  motorista_id uuid references public.motoristas(id) on delete set null,
  veiculo_id uuid references public.veiculos(id) on delete set null,
  ativo boolean not null default true,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pontos_rota (
  id uuid primary key default gen_random_uuid(),
  rota_id uuid not null references public.rotas(id) on delete cascade,
  nome text not null,
  endereco text not null,
  bairro text,
  horario time,
  ordem integer not null check (ordem > 0),
  created_at timestamptz not null default now(),
  constraint pontos_rota_ordem_unique unique (rota_id, ordem)
);

create index if not exists rotas_ativo_idx on public.rotas (ativo);
create index if not exists rotas_motorista_idx on public.rotas (motorista_id);
create index if not exists rotas_veiculo_idx on public.rotas (veiculo_id);
create index if not exists pontos_rota_rota_ordem_idx
  on public.pontos_rota (rota_id, ordem);

alter table public.rotas enable row level security;
alter table public.pontos_rota enable row level security;

drop policy if exists "Administradores gerenciam rotas" on public.rotas;
create policy "Administradores gerenciam rotas"
  on public.rotas for all to authenticated
  using (public.fretapp_usuario_e_administrador())
  with check (public.fretapp_usuario_e_administrador());

drop policy if exists "Administradores gerenciam pontos de rota" on public.pontos_rota;
create policy "Administradores gerenciam pontos de rota"
  on public.pontos_rota for all to authenticated
  using (public.fretapp_usuario_e_administrador())
  with check (public.fretapp_usuario_e_administrador());

grant select, insert, update, delete on public.rotas to authenticated;
grant select, insert, update, delete on public.pontos_rota to authenticated;
