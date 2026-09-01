# ams-translator-traducoes

Biblioteca de traduções **PT-BR** para o app
[**AMS Translator**](https://github.com/alehandromendes/ams-translator).

O app lê o [`index.json`](index.json) daqui, resolve a **dependência** da tradução
(quando existe — ex.: a base em inglês do CPDD, baixada do repositório **oficial**
dele, nunca hospedada aqui), baixa os arquivos da tradução PT e instala na pasta do
jogo, com backup do original e um clique pra restaurar.

**Multi-jogo por design:** o `.exe` do AMS Translator não embute nada específico de
um jogo. Tudo — mod loader, camada de tradução em runtime e a memória de tradução —
vem daqui, por jogo, sob demanda.

## Jogos

| Jogo | Ponte de tradução | Base |
|------|-------------------|------|
| Lord of Mysteries (诡秘之主) | 中文 → EN → PT-BR | [CPDD English patch](https://github.com/Lani27/lord-of-mysteries-english-patch) |

O jogo é em chinês. O **CPDD English patch** já faz 中文 → inglês; este repositório
traduz o **inglês do patch → PT-BR em runtime**, então a tradução completa é uma
ponte **中文 → EN → PT-BR** (o inglês serve de pivô — nomes próprios já vêm
anglicizados, e a tradução EN→PT sai melhor que CN→PT direto).

### `lord-of-mysteries/pt/` — o mod `tl_translate` completo

- `Init.lua` — carregado pelo `LOMModLoader` do CPDD via `cpdd_user_settings.lua`
  (um arquivo de usuário que o CPDD nunca sobrescreve). Não modifica nenhum
  arquivo do CPDD.
- `hotpatch.lua` — a camada de tradução em runtime: varre os dados carregados e
  troca EN→PT usando a memória de tradução + um dicionário curado de rótulos de
  UI (menus, skills, itens). Tem hot-reload em dev e recompila só uma vez em
  produção (sem custo de I/O por tick).
- `_en2pt_1..9.lua` — memória de tradução (~125 mil pares EN→PT).
- `cpdd_*.lua`, `Data_Excel_*.lua` — dados por módulo do StringDB do jogo.

## Como funciona

Cada entrada de `index.json` descreve:

- `default_dirs` / `game_markers` — onde e como o app acha a raiz do jogo
- `dependency` — a base que a tradução precisa (ex.: o CPDD English patch). O app
  detecta se está instalada; se não, baixa o **instalador oficial** da fonte dela
  (`direct_url` / `page_url`) e abre o wizard. **Nada da dependência é hospedado
  aqui.**
- `files` — `src` (arquivo neste repo) → `dest` (caminho relativo à raiz do jogo,
  já resolvendo onde cada arquivo do mod vai)

As traduções são geradas por **tradução automática** sobre a camada em inglês da
dependência (ponte 中文 → EN → PT-BR). Não redistribuímos conteúdo do jogo nem da
dependência.

## Contribuir

Correções de termos entram no
[`game_terms.csv`](https://github.com/alehandromendes/ams-translator/blob/main/overlay/gamefill/game_terms.csv)
do app, ou direto no `hotpatch.lua` (dicionário `OVR` / `MENU_PT`) pra rótulos
curtos de UI. Pra regenerar a memória de tradução:
`python -m overlay.gamefill.patch_pt` (veja o README do app).

---

## Sobre a tradução

As traduções deste repositório são feitas por **inteligência artificial** (tradução
automática, sem revisão humana linha a linha), com **estratégias de desambiguação
voltadas a jogos**:

- **Dicionário de termos ambíguos** ([`game_terms.csv`](https://github.com/alehandromendes/ams-translator/blob/main/overlay/gamefill/game_terms.csv))
  — fixa o sentido correto de palavras que teriam duas leituras: *gear* → equipamento
  (não "engrenagem"), *cast* → conjurar (não "elenco"), *dungeon* → masmorra,
  *cooldown* → recarga, *raid* → raide…
- **Termos do universo preservados** — *Beyonder*, *Sequência*, *Caminho*,
  *Vigia Noturno*, *Marionete*, *Semideus*, nomes próprios do glossário.
- **Marcação protegida** — tags de formatação (`<InvHighlight>`, `<Mark id=…>`),
  variáveis (`%s`, `{0}`) e quebras de linha passam intactas pela tradução.

Mesmo assim, é tradução de máquina: pode ter escorregões. O app **guarda o arquivo
original** antes de instalar e restaura em um clique.
