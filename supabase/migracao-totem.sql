-- Modo totem: a tela de agradecimento volta sozinha para o início.
-- 0 = não voltar sozinho.
alter table public.config
  add column if not exists segundos_retorno smallint not null default 8;

alter table public.config
  drop constraint if exists config_segundos_retorno_check;

alter table public.config
  add constraint config_segundos_retorno_check
  check (segundos_retorno between 0 and 120);
