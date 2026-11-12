-- FretApp: comunicados administrativos e caixa de entrada.
create table if not exists public.mensagens (
  id uuid primary key default gen_random_uuid(),
  titulo text not null check (char_length(btrim(titulo)) between 3 and 120),
  conteudo text not null check (char_length(btrim(conteudo)) between 1 and 5000),
  publico_alvo text not null default 'todos'
    check (publico_alvo in ('todos', 'passageiros', 'motoristas')),
  prioridade text not null default 'normal'
    check (prioridade in ('normal', 'importante', 'urgente')),
  publicada boolean not null default true,
  publicado_em timestamptz not null default now(),
  criado_por uuid references public.perfis(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists idx_mensagens_publicadas
  on public.mensagens (publicada, publicado_em desc);

create table if not exists public.mensagens_lidas (
  mensagem_id uuid not null references public.mensagens(id) on delete cascade,
  usuario_id uuid not null references public.perfis(id) on delete cascade,
  lida_em timestamptz not null default now(),
  primary key (mensagem_id, usuario_id)
);

create index if not exists idx_mensagens_lidas_usuario
  on public.mensagens_lidas (usuario_id, lida_em desc);

alter table public.mensagens enable row level security;
alter table public.mensagens_lidas enable row level security;

drop policy if exists "Administradores gerenciam mensagens" on public.mensagens;
create policy "Administradores gerenciam mensagens"
  on public.mensagens for all to authenticated
  using (public.fretapp_usuario_e_administrador())
  with check (public.fretapp_usuario_e_administrador());

drop policy if exists "Usuários recebem mensagens destinadas ao seu perfil" on public.mensagens;
create policy "Usuários recebem mensagens destinadas ao seu perfil"
  on public.mensagens for select to authenticated
  using (
    publicada = true
    and exists (
      select 1
      from public.perfis p
      where p.id = (select auth.uid())
        and (
          mensagens.publico_alvo = 'todos'
          or (mensagens.publico_alvo = 'passageiros' and p.tipo = 'passageiro')
          or (mensagens.publico_alvo = 'motoristas' and p.tipo = 'motorista')
          or p.tipo = 'administrador'
        )
    )
  );

drop policy if exists "Usuários consultam suas leituras" on public.mensagens_lidas;
create policy "Usuários consultam suas leituras"
  on public.mensagens_lidas for select to authenticated
  using (usuario_id = (select auth.uid()));

drop policy if exists "Usuários registram suas leituras" on public.mensagens_lidas;
create policy "Usuários registram suas leituras"
  on public.mensagens_lidas for insert to authenticated
  with check (usuario_id = (select auth.uid()));

grant select, insert, update, delete on public.mensagens to authenticated;
grant select, insert on public.mensagens_lidas to authenticated;
