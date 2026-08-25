-- ---------------------------------------------------------------------
-- Ilustração de cada área na tela de escolha da pesquisa.
-- Pode rodar quantas vezes quiser: não duplica nada.
-- ---------------------------------------------------------------------
alter table public.areas add column if not exists icone text;

do $$
begin
  if not exists (
    select 1 from information_schema.constraint_column_usage
    where table_name = 'areas' and constraint_name = 'areas_icone_check'
  ) then
    alter table public.areas
      add constraint areas_icone_check check (char_length(icone) <= 30);
  end if;
end $$;

-- Preenche as áreas que já existem, pelo nome.
update public.areas set icone = 'fisioterapia'
 where icone is null and nome ~* 'fisio|pilates|rpg|reabilit';

update public.areas set icone = 'psicologia'
 where icone is null and nome ~* 'psic|terapia|mental';

update public.areas set icone = 'odontologia'
 where icone is null and nome ~* 'odont|dent|bucal|orto';

update public.areas set icone = 'folha' where icone is null;

select nome, icone from public.areas order by ordem;
