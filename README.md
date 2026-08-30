# tradutor-legendas-traducoes

Biblioteca de traduções **PT-BR** para o app
[**Tradutor de Legendas**](https://github.com/alehandromendes/tradutor-legendas).

O app lê o [`index.json`](index.json) daqui, baixa os arquivos da tradução do jogo
escolhido e instala na pasta do jogo (com backup do original e um clique pra
restaurar).

## Jogos

| Jogo | Ponte de tradução | Base |
|------|-------------------|------|
| Lord of Mysteries (诡秘之主) | 中文 → EN → PT-BR | [CPDD English patch](https://github.com/Lani27/lord-of-mysteries-english-patch) |

O jogo é em chinês. O **CPDD English patch** já faz 中文 → inglês; este repositório
traduz o **inglês do patch → PT-BR**, então a tradução completa é uma ponte
**中文 → EN → PT-BR** (o inglês serve de pivô — nomes próprios já vêm anglicizados,
e a tradução EN→PT sai melhor que CN→PT direto).

## Como funciona

Cada entrada de `index.json` descreve:

- `default_dirs` — onde o app procura a pasta do jogo automaticamente
- `requires` — o que precisa existir nessa pasta pra tradução ser compatível
- `files` — `src` (arquivo aqui no repo) → `dest` (caminho relativo dentro da pasta do jogo)

As traduções são geradas por **tradução automática** (EN → PT-BR, sem chave de API)
sobre os arquivos do mod de tradução para inglês que o usuário já tem instalado.
Não redistribuímos conteúdo original do jogo.

## Contribuir

Correções de termos entram no
[`game_terms.csv`](https://github.com/alehandromendes/tradutor-legendas/blob/main/overlay/gamefill/game_terms.csv)
do app. Pra regenerar uma tradução:
`python -m overlay.gamefill.patch_pt` (veja o README do app).
