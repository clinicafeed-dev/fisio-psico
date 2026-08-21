-- =====================================================================
--  Acrescenta: SUS/Particular e a área de Odontologia
--  Pode rodar mais de uma vez sem quebrar nada.
-- =====================================================================

-- 1. Pergunta de SUS ou particular (editável no painel)
alter table public.config
  add column if not exists usar_convenio boolean not null default true,
  add column if not exists pergunta_convenio text not null default 'O seu atendimento foi pelo SUS ou particular?',
  add column if not exists opcoes_convenio text not null default 'SUS, Particular';

-- 2. Guardar a resposta
alter table public.respostas
  add column if not exists convenio text check (char_length(convenio) <= 40);

create index if not exists respostas_convenio_idx on public.respostas (convenio);

-- 3. Área de Odontologia com as perguntas próprias
do $$
declare v_odonto uuid;
begin
  select id into v_odonto from public.areas where lower(nome) = 'odontologia' limit 1;
  if v_odonto is not null then return; end if;

  insert into public.areas (nome, descricao, ordem)
  values ('Odontologia', 'Consultas, procedimentos e tratamento dentário', 3)
  returning id into v_odonto;

  insert into public.perguntas (area_id, titulo, ajuda, tipo, ordem) values
    (v_odonto, 'O dentista explicou o tratamento e as opções antes de começar?',
               'Se você entendeu o que ia ser feito e por quê.', 'escala', 10),
    (v_odonto, 'O controle da dor durante o procedimento foi adequado?',
               'Anestesia, cuidado e atenção ao seu desconforto.', 'escala', 11),
    (v_odonto, 'O consultório e os instrumentos pareciam limpos e esterilizados?',
               null, 'escala', 12),
    (v_odonto, 'Foi fácil conseguir horário para dar continuidade ao tratamento?',
               null, 'escala', 13),
    (v_odonto, 'Você recebeu orientação de cuidados depois do procedimento?',
               null, 'sim_nao', 14);
end $$;
