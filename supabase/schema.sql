-- =====================================================================
--  Pesquisa de satisfação — Fisioterapia e Psicologia
--  Cole tudo no SQL Editor do Supabase e clique em Run.
--  Pode rodar mais de uma vez sem quebrar nada.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Quem administra
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  email     text,
  criado_em timestamptz not null default now()
);

create or replace function public.eh_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ---------------------------------------------------------------------
-- 2. Textos da clínica (editáveis pelo painel)
-- ---------------------------------------------------------------------
create table if not exists public.config (
  id                smallint primary key default 1 check (id = 1),
  nome_clinica      text not null default 'Clínica de Fisioterapia e Psicologia',
  titulo_pesquisa   text not null default 'Como foi o seu atendimento?',
  texto_abertura    text not null default 'São poucas perguntas, leva menos de um minuto. Sua resposta ajuda a gente a cuidar melhor de você e de quem vem depois.',
  texto_agradecimento text not null default 'Obrigado por responder. Sua opinião chega direto para a coordenação da clínica.',
  rodape            text not null default 'Suas respostas são confidenciais e usadas apenas para melhorar o atendimento.',
  aviso_sigilo      text not null default 'Você pode responder sem se identificar. Nada do que escrever aqui vai para o seu prontuário nem para o seu profissional individualmente.',

  -- primeira pergunta da pesquisa: SUS ou particular
  usar_convenio     boolean not null default true,
  pergunta_convenio text not null default 'O seu atendimento foi pelo SUS ou particular?',
  opcoes_convenio   text not null default 'SUS, Particular',

  -- modo totem: volta sozinho para a tela inicial (0 = não voltar)
  segundos_retorno  smallint not null default 8 check (segundos_retorno between 0 and 120),

  atualizado_em     timestamptz not null default now()
);

insert into public.config (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 3. Áreas de atendimento (fisioterapia, psicologia, ...)
-- ---------------------------------------------------------------------
create table if not exists public.areas (
  id        uuid primary key default gen_random_uuid(),
  nome      text not null check (char_length(nome) between 1 and 60),
  descricao text check (char_length(descricao) <= 200),
  -- Ilustração que aparece no cartão da área, escolhida no painel.
  -- Valores: fisioterapia, psicologia, odontologia, estetoscopio, folha.
  icone     text check (char_length(icone) <= 30),
  ordem     smallint not null default 0,
  ativa     boolean not null default true,
  criado_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. Profissionais
-- ---------------------------------------------------------------------
create table if not exists public.profissionais (
  id        uuid primary key default gen_random_uuid(),
  area_id   uuid references public.areas(id) on delete set null,
  nome      text not null check (char_length(nome) between 1 and 80),
  ordem     smallint not null default 0,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);

create index if not exists profissionais_area_idx on public.profissionais (area_id);

-- ---------------------------------------------------------------------
-- 5. Perguntas
--    tipo:  'nota'    -> 0 a 10 (a nota geral da experiência)
--           'escala'  -> 1 a 5  (muito ruim ... excelente)
--           'sim_nao' -> sim / não
--           'texto'   -> resposta escrita
--    area_id nulo = pergunta vale para todas as áreas
-- ---------------------------------------------------------------------
create table if not exists public.perguntas (
  id         uuid primary key default gen_random_uuid(),
  area_id    uuid references public.areas(id) on delete cascade,
  titulo     text not null check (char_length(titulo) between 1 and 200),
  ajuda      text check (char_length(ajuda) <= 300),
  tipo       text not null default 'escala' check (tipo in ('nota','escala','sim_nao','texto')),
  ordem      smallint not null default 0,
  obrigatoria boolean not null default false,
  ativa      boolean not null default true,
  criado_em  timestamptz not null default now()
);

create index if not exists perguntas_area_idx on public.perguntas (area_id, ordem);

-- ---------------------------------------------------------------------
-- 6. Respostas
-- ---------------------------------------------------------------------
create table if not exists public.respostas (
  id             uuid primary key default gen_random_uuid(),
  criado_em      timestamptz not null default now(),
  convenio       text check (char_length(convenio) <= 40),
  area_id        uuid references public.areas(id) on delete set null,
  area_nome      text check (char_length(area_nome) <= 60),
  profissional_id uuid references public.profissionais(id) on delete set null,
  profissional_nome text check (char_length(profissional_nome) <= 80),
  nota           smallint check (nota between 0 and 10),
  comentario     text check (char_length(comentario) <= 2000),
  nome           text check (char_length(nome) <= 120),
  contato        text check (char_length(contato) <= 120),
  autoriza       boolean not null default false,
  retornado_em   timestamptz,
  retornado_por  text check (char_length(retornado_por) <= 120),
  retorno_nota   text check (char_length(retorno_nota) <= 1000)
);

create index if not exists respostas_criado_em_idx on public.respostas (criado_em desc);
create index if not exists respostas_area_idx      on public.respostas (area_id);
create index if not exists respostas_convenio_idx  on public.respostas (convenio);

create table if not exists public.resposta_itens (
  id            uuid primary key default gen_random_uuid(),
  resposta_id   uuid not null references public.respostas(id) on delete cascade,
  pergunta_id   uuid references public.perguntas(id) on delete set null,
  pergunta_titulo text check (char_length(pergunta_titulo) <= 200),
  tipo          text check (char_length(tipo) <= 20),
  valor_num     smallint check (valor_num between 0 and 10),
  valor_texto   text check (char_length(valor_texto) <= 2000)
);

create index if not exists resposta_itens_resposta_idx on public.resposta_itens (resposta_id);
create index if not exists resposta_itens_pergunta_idx on public.resposta_itens (pergunta_id);

-- ---------------------------------------------------------------------
-- 7. Regras de acesso (Row Level Security)
--
--    A chave pública do site precisa LER o conteúdo da pesquisa
--    (textos, áreas, profissionais, perguntas) para conseguir montá-la,
--    e precisa ESCREVER as respostas. Só isso.
--
--    Ler respostas e editar qualquer configuração exige login de
--    administrador cadastrado na tabela admins.
-- ---------------------------------------------------------------------
alter table public.admins         enable row level security;
alter table public.config         enable row level security;
alter table public.areas          enable row level security;
alter table public.profissionais  enable row level security;
alter table public.perguntas      enable row level security;
alter table public.respostas      enable row level security;
alter table public.resposta_itens enable row level security;

-- admins: cada um enxerga só a própria linha
drop policy if exists "admin ve a propria linha" on public.admins;
create policy "admin ve a propria linha"
  on public.admins for select to authenticated
  using (user_id = auth.uid());

-- config / areas / profissionais / perguntas: leitura pública, escrita só admin
drop policy if exists "todos leem config" on public.config;
create policy "todos leem config"
  on public.config for select to anon, authenticated using (true);

drop policy if exists "admin edita config" on public.config;
create policy "admin edita config"
  on public.config for update to authenticated
  using (public.eh_admin()) with check (public.eh_admin());

drop policy if exists "todos leem areas" on public.areas;
create policy "todos leem areas"
  on public.areas for select to anon, authenticated using (true);

drop policy if exists "admin gerencia areas" on public.areas;
create policy "admin gerencia areas"
  on public.areas for all to authenticated
  using (public.eh_admin()) with check (public.eh_admin());

drop policy if exists "todos leem profissionais" on public.profissionais;
create policy "todos leem profissionais"
  on public.profissionais for select to anon, authenticated using (true);

drop policy if exists "admin gerencia profissionais" on public.profissionais;
create policy "admin gerencia profissionais"
  on public.profissionais for all to authenticated
  using (public.eh_admin()) with check (public.eh_admin());

drop policy if exists "todos leem perguntas" on public.perguntas;
create policy "todos leem perguntas"
  on public.perguntas for select to anon, authenticated using (true);

drop policy if exists "admin gerencia perguntas" on public.perguntas;
create policy "admin gerencia perguntas"
  on public.perguntas for all to authenticated
  using (public.eh_admin()) with check (public.eh_admin());

-- respostas: paciente só INSERE; admin lê e registra retorno
drop policy if exists "paciente envia resposta" on public.respostas;
create policy "paciente envia resposta"
  on public.respostas for insert to anon, authenticated with check (true);

drop policy if exists "admin le respostas" on public.respostas;
create policy "admin le respostas"
  on public.respostas for select to authenticated
  using (public.eh_admin());

drop policy if exists "admin registra retorno" on public.respostas;
create policy "admin registra retorno"
  on public.respostas for update to authenticated
  using (public.eh_admin()) with check (public.eh_admin());

drop policy if exists "paciente envia itens" on public.resposta_itens;
create policy "paciente envia itens"
  on public.resposta_itens for insert to anon, authenticated with check (true);

drop policy if exists "admin le itens" on public.resposta_itens;
create policy "admin le itens"
  on public.resposta_itens for select to authenticated
  using (public.eh_admin());

-- Nenhuma política de DELETE em respostas: ninguém apaga pela API.
-- Para excluir (pedido de exclusão de dados), use o Table Editor do Supabase.

-- ---------------------------------------------------------------------
-- 8. Conteúdo inicial (só na primeira vez)
-- ---------------------------------------------------------------------
do $$
declare
  v_fisio uuid;
  v_psico uuid;
  v_odonto uuid;
begin
  if exists (select 1 from public.areas) then
    return;
  end if;

  insert into public.areas (nome, descricao, icone, ordem)
  values ('Fisioterapia', 'Sessões de reabilitação e tratamento físico', 'fisioterapia', 1)
  returning id into v_fisio;

  insert into public.areas (nome, descricao, icone, ordem)
  values ('Psicologia', 'Atendimento psicológico individual ou em grupo', 'psicologia', 2)
  returning id into v_psico;

  insert into public.areas (nome, descricao, icone, ordem)
  values ('Odontologia', 'Consultas, procedimentos e tratamento dentário', 'odontologia', 3)
  returning id into v_odonto;

  -- Perguntas de todas as áreas (area_id nulo)
  insert into public.perguntas (area_id, titulo, ajuda, tipo, ordem, obrigatoria) values
    (null, 'De 0 a 10, o quanto você indicaria a nossa clínica para alguém próximo?',
           '0 é "de jeito nenhum" e 10 é "com certeza".', 'nota', 1, true),
    (null, 'Como foi o atendimento da recepção?',
           'Acolhimento, simpatia e clareza das informações.', 'escala', 2, false),
    (null, 'Foi fácil marcar e remarcar o seu horário?',
           'Telefone, WhatsApp, presencial — como foi agendar.', 'escala', 3, false),
    (null, 'O horário marcado foi respeitado?',
           'Se você esperou muito além do combinado, conte no final.', 'escala', 4, false),
    (null, 'A estrutura estava limpa e confortável?',
           'Sala de espera, salas de atendimento e banheiros.', 'escala', 5, false);

  -- Perguntas só da fisioterapia
  insert into public.perguntas (area_id, titulo, ajuda, tipo, ordem) values
    (v_fisio, 'O profissional explicou o que ia ser feito na sessão?',
              'Se você entendeu o objetivo de cada exercício.', 'escala', 10, false),
    (v_fisio, 'Você sentiu evolução no seu problema desde que começou?',
              'Dor, movimento, força — o que te trouxe aqui.', 'escala', 11, false),
    (v_fisio, 'Os equipamentos e materiais estavam em boas condições?',
              null, 'escala', 12, false),
    (v_fisio, 'Você recebeu orientação de exercícios para fazer em casa?',
              null, 'sim_nao', 13, false);

  -- Perguntas só da psicologia
  insert into public.perguntas (area_id, titulo, ajuda, tipo, ordem) values
    (v_psico, 'Você se sentiu acolhido e respeitado durante a sessão?',
              'Sem julgamento, no seu tempo.', 'escala', 10, false),
    (v_psico, 'Você sentiu que teve privacidade no atendimento?',
              'Sala reservada, conversa não ouvida de fora.', 'escala', 11, false),
    (v_psico, 'O tempo da sessão foi suficiente para você?',
              null, 'escala', 12, false),
    (v_psico, 'Você se sentiu à vontade para falar o que precisava?',
              null, 'escala', 13, false),
    (v_psico, 'Você pretende continuar o acompanhamento?',
              null, 'sim_nao', 14, false);

  -- Perguntas só da odontologia
  insert into public.perguntas (area_id, titulo, ajuda, tipo, ordem, obrigatoria) values
    (v_odonto, 'O dentista explicou o tratamento e as opções antes de começar?',
               'Se você entendeu o que ia ser feito e por quê.', 'escala', 10, false),
    (v_odonto, 'O controle da dor durante o procedimento foi adequado?',
               'Anestesia, cuidado e atenção ao seu desconforto.', 'escala', 11, false),
    (v_odonto, 'O consultório e os instrumentos pareciam limpos e esterilizados?',
               null, 'escala', 12, false),
    (v_odonto, 'Foi fácil conseguir horário para dar continuidade ao tratamento?',
               null, 'escala', 13, false),
    (v_odonto, 'Você recebeu orientação de cuidados depois do procedimento?',
               null, 'sim_nao', 14, false);
end $$;

-- ---------------------------------------------------------------------
-- 9. Cadastrar o primeiro administrador
--    Antes: Authentication › Users › Add user › Send invitation
--    Depois troque o e-mail e rode:
-- ---------------------------------------------------------------------
-- insert into public.admins (user_id, email)
-- select id, email from auth.users where email = 'voce@suaclinica.com.br'
-- on conflict (user_id) do nothing;
