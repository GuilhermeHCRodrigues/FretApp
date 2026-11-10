-- Expande o cadastro de veículos do FretApp.
-- As colunas novas aceitam NULL para preservar os veículos já cadastrados.
-- Execute este arquivo no SQL Editor do Supabase antes de usar o formulário atualizado.

alter table public.veiculos
  add column if not exists marca text,
  add column if not exists ano_fabricacao integer,
  add column if not exists ano_modelo integer,
  add column if not exists cor text,
  add column if not exists tipo text,
  add column if not exists chassi_final varchar(7),
  add column if not exists motor_final varchar(7),
  add column if not exists renavam varchar(11),
  add column if not exists uf char(2),
  add column if not exists municipio text,
  add column if not exists quilometragem integer,
  add column if not exists combustivel text,
  add column if not exists observacoes text;
