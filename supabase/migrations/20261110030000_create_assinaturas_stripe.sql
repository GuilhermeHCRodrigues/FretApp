-- Financeiro do passageiro integrado ao Stripe (assinatura mensal).
-- Execute no SQL Editor do Supabase.
--
-- Regra de segurança: o app (chave publishable + usuário logado) só LÊ.
-- Quem grava é a Edge Function stripe-webhook, usando a service_role
-- (que ignora RLS e fica só no servidor do Supabase).

create table if not exists public.assinaturas (
  passageiro_id uuid primary key
    references public.perfis(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  -- Status do Stripe: active, past_due, incomplete, unpaid, canceled...
  status text,
  valor_centavos integer,
  moeda text,
  -- Fim do período atual = próximo vencimento.
  periodo_fim timestamptz,
  cancelar_no_fim boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.pagamentos (
  -- ID da fatura no Stripe (in_...). Evita duplicar ao reprocessar webhook.
  id text primary key,
  passageiro_id uuid not null
    references public.perfis(id) on delete cascade,
  valor_centavos integer not null,
  moeda text not null,
  -- Status da fatura: paid, open, uncollectible, void
  status text not null,
  pago_em timestamptz,
  url_fatura text,
  criado_em timestamptz not null default now()
);

create index if not exists pagamentos_passageiro_idx
  on public.pagamentos (passageiro_id, criado_em desc);

alter table public.assinaturas enable row level security;
alter table public.pagamentos enable row level security;

-- Cliente não grava nada nessas tabelas.
revoke insert, update, delete on public.assinaturas from anon, authenticated;
revoke insert, update, delete on public.pagamentos from anon, authenticated;
revoke all on public.assinaturas from anon;
revoke all on public.pagamentos from anon;
grant select on public.assinaturas to authenticated;
grant select on public.pagamentos to authenticated;

drop policy if exists "Passageiro le propria assinatura" on public.assinaturas;
create policy "Passageiro le propria assinatura"
on public.assinaturas
for select
to authenticated
using (
  passageiro_id = (select auth.uid())
  or public.fretapp_usuario_e_administrador()
);

drop policy if exists "Passageiro le proprios pagamentos" on public.pagamentos;
create policy "Passageiro le proprios pagamentos"
on public.pagamentos
for select
to authenticated
using (
  passageiro_id = (select auth.uid())
  or public.fretapp_usuario_e_administrador()
);
