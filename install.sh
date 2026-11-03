#!/usr/bin/env bash
#
# Instala o hot-pillow na barra do Omarchy.
#
# O que ele faz:
#   1. Copia o script para ~/.local/bin/hot-pillow
#   2. Cria ~/.config/hot-pillow/config (só se ainda não existir)
#   3. Faz backup do ~/.config/omarchy/shell.json e coloca os dois widgets
#      na barra (lado direito, antes do brilho da tela)
#
# Pode rodar de novo sem medo: ele não duplica nada.

set -e
cd "$(dirname "$0")"

DESTINO_SCRIPT="$HOME/.local/bin/hot-pillow"
DESTINO_CONFIG="$HOME/.config/hot-pillow/config"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
SHELL_JSON_PADRAO="${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json"

# Os dois widgets que vão para a barra.
WIDGETS='[
  {
    "id": "hot-pillow",
    "type": "command",
    "exec": "~/.local/bin/hot-pillow",
    "interval": 5,
    "tooltip": "Temperatura",
    "onClick": "omarchy-launch-or-focus-tui btop"
  },
  {
    "id": "hot-pillow-alertas",
    "type": "command",
    "exec": "~/.local/bin/hot-pillow alertas",
    "interval": 1,
    "onClick": "~/.local/bin/hot-pillow zerar"
  }
]'

# --- Conferências -----------------------------------------------------------

if ! command -v jq > /dev/null; then
  echo "Erro: precisa do 'jq' (no Omarchy ele já vem instalado)." >&2
  exit 1
fi

if [[ ! -f "$SHELL_JSON" && ! -f "$SHELL_JSON_PADRAO" ]]; then
  echo "Erro: não achei a configuração da barra do Omarchy." >&2
  echo "O hot-pillow (por enquanto) só funciona no Omarchy." >&2
  exit 1
fi

# --- 1. Script --------------------------------------------------------------

install -D -m 755 hot-pillow "$DESTINO_SCRIPT"
echo "✓ Script instalado em $DESTINO_SCRIPT"

# --- 2. Configuração --------------------------------------------------------

if [[ -f "$DESTINO_CONFIG" ]]; then
  echo "✓ Configuração já existe, mantive a sua: $DESTINO_CONFIG"
else
  install -D -m 644 config.example "$DESTINO_CONFIG"
  echo "✓ Configuração criada em $DESTINO_CONFIG"
fi

# --- 3. Barra ---------------------------------------------------------------

# Se você nunca mexeu na barra, o arquivo ainda não existe: começa do padrão.
if [[ ! -f "$SHELL_JSON" ]]; then
  install -D -m 644 "$SHELL_JSON_PADRAO" "$SHELL_JSON"
fi

if jq -e '[.bar.layout[][]?.id] | index("hot-pillow")' "$SHELL_JSON" > /dev/null; then
  echo "✓ Widgets já estão na barra"
else
  backup="$SHELL_JSON.bak.hot-pillow-$(date +%Y%m%d-%H%M%S)"
  cp "$SHELL_JSON" "$backup"
  echo "✓ Backup da barra em $backup"

  # Coloca os widgets antes do "omarchy.monitor" (brilho) ou, se ele não
  # estiver na barra, no fim do lado direito.
  jq --argjson novos "$WIDGETS" '
    (.bar.layout.right // []) as $direita
    | ($direita | map(.id) | index("omarchy.monitor")) as $posicao
    | .bar.layout.right =
        if $posicao == null then $direita + $novos
        else $direita[:$posicao] + $novos + $direita[$posicao:]
        end
  ' "$SHELL_JSON" > "$SHELL_JSON.tmp"
  mv "$SHELL_JSON.tmp" "$SHELL_JSON"
  echo "✓ Widgets adicionados na barra"
fi

echo
echo "Pronto! A temperatura aparece na barra em alguns segundos."
echo "Para mudar o limite de alerta, edite: $DESTINO_CONFIG"
