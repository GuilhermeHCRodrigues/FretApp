-- FretApp: mensalidades e pagamentos
-- Uma mensalidade por passageiro e competência; permite pagamentos parciais.

create table if not exists public.mensalidades (
  id uuid primary key default gen_random_uuid(),
  passageiro_id uuid not null references public.passageiros(id) on delete restrict,
  competencia date not null,
  valor numeric(10,2) not null check (valor > 0),
  vencimento date not null,
  descricao text,
  criado_em timestamptz not null default now(),
  constraint mensalidades_passageiro_competencia_unique
    unique (passageiro_id, competencia),
  constraint mensalidades_competencia_inicio_mes
    check (extract(day from competencia) = 1)
);

create table if not exists public.pagamentos (
  id uuid primary key default gen_random_uuid(),
  mensalidade_id uuid not null references public.mensalidades(id) on delete restrict,
  valor numeric(10,2) not null check (valor > 0),
  pago_em timestamptz not null default now(),
  forma_pagamento text not null default 'pix'
    check (forma_pagamento in ('pix', 'dinheiro', 'transferencia', 'cartao', 'outro')),
  observacao text,
  criado_em timestamptz not null default now()
);

create index if not exists idx_mensalidades_competencia_vencimento
  on public.mensalidades (competencia, vencimento);
create index if not exists idx_mensalidades_passageiro
  on public.mensalidades (passageiro_id);
create index if not exists idx_pagamentos_mensalidade
  on public.pagamentos (mensalidade_id);
create index if not exists idx_pagamentos_pago_em
  on public.pagamentos (pago_em);

alter table public.mensalidades enable row level security;
alter table public.pagamentos enable row level security;

drop policy if exists "Administradores gerenciam mensalidades" on public.mensalidades;
create policy "Administradores gerenciam mensalidades"
  on public.mensalidades for all to authenticated
  using (public.fretapp_usuario_e_administrador())
  with check (public.fretapp_usuario_e_administrador());

drop policy if exists "Administradores gerenciam pagamentos" on public.pagamentos;
create policy "Administradores gerenciam pagamentos"
  on public.pagamentos for all to authenticated
  using (public.fretapp_usuario_e_administrador())
  with check (public.fretapp_usuario_e_administrador());

grant select, insert, update, delete on public.mensalidades to authenticated;
grant select, insert, update, delete on public.pagamentos to authenticated;
