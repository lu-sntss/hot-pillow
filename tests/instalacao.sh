#!/usr/bin/env bash
#
# Testa install.sh e uninstall.sh numa "home de mentira", sem tocar na sua
# barra de verdade.
#
# Rodar: ./tests/instalacao.sh

cd "$(dirname "$0")/.." || exit 1
PROJETO="$PWD"

PASTA_TESTE=$(mktemp -d)
trap 'rm -rf "$PASTA_TESTE"' EXIT

export HOME="$PASTA_TESTE/home"
export XDG_RUNTIME_DIR="$PASTA_TESTE/run"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
mkdir -p "$HOME/.config/omarchy" "$XDG_RUNTIME_DIR"

passou=0
falhou=0

confere() {
  if [[ "$2" == "$3" ]]; then
    echo "  ok    $1"
    passou=$(( passou + 1 ))
  else
    echo "  FALHA $1"
    echo "        esperado: $3"
    echo "        obtido:   $2"
    falhou=$(( falhou + 1 ))
  fi
}

ids_da_direita() {
  jq -r '.bar.layout.right | map(.id) | join(" ")' "$SHELL_JSON"
}

quantos_backups() {
  find "$HOME/.config/omarchy" -name 'shell.json.bak.hot-pillow-*' | wc -l
}

# Uma barra parecida com a do Omarchy.
cat > "$SHELL_JSON" << 'EOF'
{
  "bar": {
    "layout": {
      "left": [{ "id": "omarchy.menu" }],
      "right": [
        { "id": "omarchy.audio" },
        { "id": "omarchy.monitor" },
        { "id": "omarchy.power" }
      ]
    }
  }
}
EOF

echo "Instalar"
"$PROJETO/install.sh" > /dev/null
confere "script instalado e executável" "$([[ -x $HOME/.local/bin/hot-pillow ]] && echo sim)" "sim"
confere "config criada" "$([[ -f $HOME/.config/hot-pillow/config ]] && echo sim)" "sim"
confere "widgets antes do brilho" "$(ids_da_direita)" \
  "omarchy.audio hot-pillow hot-pillow-alertas omarchy.monitor omarchy.power"
confere "fez backup" "$(quantos_backups)" "1"

echo "Instalar de novo"
echo "ALERTA_TEMP=60" > "$HOME/.config/hot-pillow/config"
sleep 1  # para o backup ter outro nome, caso fosse criado
"$PROJETO/install.sh" > /dev/null
confere "não duplica widgets" "$(ids_da_direita)" \
  "omarchy.audio hot-pillow hot-pillow-alertas omarchy.monitor omarchy.power"
confere "não apaga a config do usuário" "$(cat "$HOME/.config/hot-pillow/config")" "ALERTA_TEMP=60"
confere "sem backup novo (nada mudou)" "$(quantos_backups)" "1"

echo "Desinstalar"
sleep 1
"$PROJETO/uninstall.sh" > /dev/null
confere "widgets removidos" "$(ids_da_direita)" "omarchy.audio omarchy.monitor omarchy.power"
confere "script removido" "$([[ -e $HOME/.local/bin/hot-pillow ]] && echo sim || echo nao)" "nao"
confere "config mantida" "$([[ -f $HOME/.config/hot-pillow/config ]] && echo sim)" "sim"
confere "fez backup antes" "$(quantos_backups)" "2"
confere "resto da barra intacto" "$(jq -r '.bar.layout.left[0].id' "$SHELL_JSON")" "omarchy.menu"

echo "Instalar sem shell.json (barra nunca mexida)"
rm "$SHELL_JSON"
mkdir -p "$PASTA_TESTE/omarchy/config/omarchy"
echo '{"bar":{"layout":{"right":[{"id":"omarchy.power"}]}}}' > "$PASTA_TESTE/omarchy/config/omarchy/shell.json"
OMARCHY_PATH="$PASTA_TESTE/omarchy" "$PROJETO/install.sh" > /dev/null
confere "cria a partir do padrão e adiciona no fim" "$(ids_da_direita)" \
  "omarchy.power hot-pillow hot-pillow-alertas"

echo
echo "Passou: $passou  Falhou: $falhou"
(( falhou == 0 ))
