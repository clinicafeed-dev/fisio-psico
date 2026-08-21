# Pesquisa de satisfação — Fisioterapia e Psicologia

**No ar:**

- Pesquisa que o paciente responde: https://clinicafeed-dev.github.io/fisio-psico/
- Painel da coordenação: https://clinicafeed-dev.github.io/fisio-psico/admin.html

Login do painel: `clinicafeed@gmail.com`. A senha é criada pelo próprio
administrador, pelo link enviado por e-mail; se esquecer, use "Esqueci minha
senha" na tela de login.

Projeto no Supabase: `clinica-fisio-psico` (região São Paulo).
Repositório do código: `clinicafeed-dev/fisio-psico`.

---

## Como o paciente vê

1. Escolhe se foi na **fisioterapia** ou na **psicologia**
2. Diz com quem foi atendido (opcional)
3. Responde as perguntas daquela área
4. Escreve o que quiser e, se quiser retorno, deixa o contato

Perguntas marcadas como "todas as áreas" aparecem para todo mundo. As outras só
para quem escolheu aquela área — é o que permite perguntar sobre exercícios em
casa na fisioterapia e sobre acolhimento e privacidade na psicologia.

**Link direto para uma área** (pula a primeira tela):

```
https://clinicafeed-dev.github.io/fisio-psico/?a=Fisioterapia
https://clinicafeed-dev.github.io/fisio-psico/?a=Psicologia
```

---

## Modo totem (tablet na recepção)

Depois que o paciente envia, a tela de agradecimento fica alguns segundos com
uma contagem regressiva e **volta sozinha para a primeira pergunta**, pronta
para o próximo. O tempo é ajustável em Configurações (`0` desliga).

Junto com isso, se alguém começar a responder e for embora no meio, o
formulário se limpa sozinho depois de 2 minutos sem ninguém tocar na tela — o
próximo paciente nunca vê o nome, o contato ou as notas de quem veio antes.

Para deixar o tablet redondo: abra o link no navegador, ative o modo tela cheia
(ou "adicionar à tela de início") e desligue a suspensão automática do aparelho.

---

## Como a coordenação vê

O painel fala português do dia a dia, não jargão de pesquisa de mercado:

| Em vez de | O painel diz |
|---|---|
| NPS | Nota média dos pacientes |
| Promotores | Saem satisfeitos (nota 9 ou 10) |
| Neutros | Ficam indiferentes (nota 7 ou 8) |
| Detratores | Saem insatisfeitos (nota 6 ou menos) |

**Abas:**

- **Resumo** — nota média, como as notas se dividem, o que fazer primeiro (com
  sugestões concretas ligadas à pergunta que foi mal) e a nota de cada pergunta
- **Comparar áreas** — fisioterapia e psicologia lado a lado, marcando qual das
  duas está atrás em cada pergunta
- **Comentários** — o que os pacientes escreveram, filtrável por satisfeitos,
  indiferentes e insatisfeitos
- **Falar com pacientes** — quem deixou contato e ainda não foi procurado;
  dá para registrar quem falou e o que ficou combinado
- **Configurações** — textos, áreas, profissionais, perguntas e os links prontos
  para copiar

Filtros de período, área e profissional valem para todas as abas de análise.
O botão **Baixar planilha** exporta um CSV que abre direto no Excel.

---

## Segurança

Tudo protegido por Row Level Security no Supabase:

| Quem | Pode |
|---|---|
| Visitante do site (chave pública) | ler os textos e as perguntas · **enviar** uma resposta |
| Administrador cadastrado em `public.admins` | ler as respostas, registrar retornos e editar as configurações |
| Ninguém pela API | apagar respostas |

A chave que fica exposta no navegador não consegue ler uma única resposta.
Cadastro público de novos usuários fica desativado: só entra quem for convidado
pelo painel do Supabase.

Para excluir uma resposta (pedido de exclusão de dados de um paciente), use o
Table Editor do Supabase — é deliberado que isso não seja possível pelo site.

---

## Instalar do zero

**1. Banco.** No Supabase, crie um projeto, abra o SQL Editor, cole todo o
conteúdo de `supabase/schema.sql` e clique em Run. Ele já cria as duas áreas e
um conjunto inicial de perguntas para fisioterapia e psicologia.

**2. Chave.** Em Project Settings › API Keys, copie a *publishable key* e o
endereço do projeto para o arquivo `config.js`.

**3. Site.** Publique `index.html`, `admin.html` e `config.js` em qualquer
hospedagem de arquivos estáticos (GitHub Pages, Cloudflare Pages, Netlify).

**4. Administrador.** Authentication › Users › Add user › **Send invitation**
para o e-mail de quem vai coordenar. A pessoa recebe um link, cria a própria
senha e entra. Depois, no SQL Editor:

```sql
insert into public.admins (user_id, email)
select id, email from auth.users where email = 'coordenacao@suaclinica.com.br'
on conflict (user_id) do nothing;
```

**5. Endereços.** Em Authentication › URL Configuration, coloque o endereço do
painel como *Site URL* e adicione `https://SEU-SITE/**` na lista de redirects —
sem isso o link de criar senha não funciona.

**6. Fechar a porta.** Em Authentication › Sign In / Providers, desligue
**Allow new users to sign up**.

---

## Arquivos

- `index.html` — pesquisa do paciente (monta a tela a partir do banco)
- `admin.html` — painel com login, análise e edição
- `config.js` — só o endereço e a chave pública do Supabase
- `supabase/schema.sql` — tabelas, regras de segurança e conteúdo inicial
