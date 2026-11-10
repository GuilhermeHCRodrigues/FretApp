-- Cria o cadastro administrativo de motoristas do FretApp.
-- Execute no SQL Editor do Supabase antes de usar a tela de Motoristas.
-- CPF e CNH são armazenados somente com números.

create table if not exists public.motoristas (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(btrim(nome)) >= 3),
  cpf varchar(11) not null unique check (cpf ~ '^[0-9]{11}$'),
  telefone varchar(11) not null check (telefone ~ '^[0-9]{10,11}$'),
  email text,
  cnh_numero varchar(11) not null unique check (cnh_numero ~ '^[0-9]{11}$'),
  cnh_categoria text not null
    check (cnh_categoria in ('ACC', 'A', 'B', 'C', 'D', 'E', 'AB', 'AC', 'AD', 'AE')),
  cnh_validade date not null,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.fretapp_usuario_e_administrador()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfis p
    where p.id = auth.uid()
      and p.tipo = 'administrador'
  );
$$;

revoke all on function public.fretapp_usuario_e_administrador() from public;
grant execute on function public.fretapp_usuario_e_administrador() to authenticated;

alter table public.motoristas enable row level security;

drop policy if exists "Administradores gerenciam motoristas"
  on public.motoristas;

create policy "Administradores gerenciam motoristas"
  on public.motoristas
  for all
  to authenticated
  using (public.fretapp_usuario_e_administrador())
  with check (public.fretapp_usuario_e_administrador());

grant select, insert, update, delete on public.motoristas to authenticated;
