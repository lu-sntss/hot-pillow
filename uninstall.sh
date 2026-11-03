#!/usr/bin/env bash
#
# Remove o hot-pillow: tira os widgets da barra (com backup antes) e apaga o
# script. A sua configuração fica guardada, caso queira instalar de novo.

set -e

DESTINO_SCRIPT="$HOME/.local/bin/hot-pillow"
DESTINO_CONFIG="$HOME/.config/hot-pillow/config"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
PASTA_ESTADO="${XDG_RUNTIME_DIR:-/tmp}/hot-pillow"

if ! command -v jq > /dev/null; then
  echo "Erro: precisa do 'jq'." >&2
  exit 1
fi

if [[ -f "$SHELL_JSON" ]] && jq -e '[.bar.layout[][]?.id] | index("hot-pillow")' "$SHELL_JSON" > /dev/null; then
  backup="$SHELL_JSON.bak.hot-pillow-$(date +%Y%m%d-%H%M%S)"
  cp "$SHELL_JSON" "$backup"
  echo "✓ Backup da barra em $backup"

  # Tira os dois widgets de todos os lados da barra.
  jq '.bar.layout |= map_values(map(select(.id != "hot-pillow" and .id != "hot-pillow-alertas")))' \
    "$SHELL_JSON" > "$SHELL_JSON.tmp"
  mv "$SHELL_JSON.tmp" "$SHELL_JSON"
  echo "✓ Widgets removidos da barra"
fi

rm -f "$DESTINO_SCRIPT"
rm -rf "$PASTA_ESTADO"
echo "✓ Script removido"

if [[ -f "$DESTINO_CONFIG" ]]; then
  echo
  echo "Sua configuração continua em $DESTINO_CONFIG"
  echo "Para apagar também: rm -r $(dirname "$DESTINO_CONFIG")"
fi
