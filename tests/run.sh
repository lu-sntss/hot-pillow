#!/usr/bin/env bash
#
# Testes do hot-pillow. Usa sensores "de mentira" numa pasta temporária,
# então dá para testar 40°C, 90°C, sensor sumido etc. sem esquentar o PC.
#
# Rodar: ./tests/run.sh

cd "$(dirname "$0")/.." || exit 1
HOT_PILLOW="$PWD/hot-pillow"

PASTA_TESTE=$(mktemp -d)
trap 'rm -rf "$PASTA_TESTE"' EXIT

export HOT_PILLOW_SENSORES="$PASTA_TESTE/hwmon"
export HOT_PILLOW_ESTADO="$PASTA_TESTE/estado"
export HOT_PILLOW_CONFIG="$PASTA_TESTE/config"

# notify-send falso: em vez de mostrar a notificação, anota num arquivo.
mkdir -p "$PASTA_TESTE/bin"
cat > "$PASTA_TESTE/bin/notify-send" << 'EOF'
#!/usr/bin/env bash
echo "$*" >> "$HOT_PILLOW_ESTADO/../notificacoes"
EOF
chmod +x "$PASTA_TESTE/bin/notify-send"
export PATH="$PASTA_TESTE/bin:$PATH"

passou=0
falhou=0

# ---------------------------------------------------------------------------
# Ajudantes
# ---------------------------------------------------------------------------

# Cria um sensor falso. Ex.: criar_sensor hwmon0 k10temp 48
criar_sensor() {
  mkdir -p "$HOT_PILLOW_SENSORES/$1"
  echo "$2" > "$HOT_PILLOW_SENSORES/$1/name"
  echo "$(( $3 * 1000 ))" > "$HOT_PILLOW_SENSORES/$1/temp1_input"
}

# Muda a temperatura de um sensor falso já criado.
mudar_temp() {
  echo "$(( $2 * 1000 ))" > "$HOT_PILLOW_SENSORES/$1/temp1_input"
}

# Começa um teste do zero: sem sensores, sem estado, sem config.
limpar() {
  rm -rf "$HOT_PILLOW_SENSORES" "$HOT_PILLOW_ESTADO" "$HOT_PILLOW_CONFIG" \
    "$PASTA_TESTE/notificacoes"
}

contar_notificacoes() {
  if [[ -f "$PASTA_TESTE/notificacoes" ]]; then
    wc -l < "$PASTA_TESTE/notificacoes"
  else
    echo 0
  fi
}

# confere "descrição" "valor obtido" "valor esperado"
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

# confere_contem "descrição" "texto" "pedaço que precisa estar no texto"
confere_contem() {
  if [[ "$2" == *"$3"* ]]; then
    confere "$1" "sim" "sim"
  else
    confere "$1" "$2" "(algo contendo) $3"
  fi
}

json_valido() {
  if jq -e . > /dev/null 2>&1 <<< "$1"; then echo sim; else echo nao; fi
}

campo() {
  jq -r ".$2 // \"\"" <<< "$1"
}

# ---------------------------------------------------------------------------
# Testes
# ---------------------------------------------------------------------------

echo "Temperatura normal"
limpar
criar_sensor hwmon0 k10temp 48
saida=$("$HOT_PILLOW")
confere "JSON válido" "$(json_valido "$saida")" "sim"
confere_contem "mostra 48°" "$(campo "$saida" text)" "48°"
confere "não acende" "$(campo "$saida" class)" ""
confere "nenhuma notificação" "$(contar_notificacoes)" "0"

echo "Passou do limite padrão (75°C)"
mudar_temp hwmon0 80
saida=$("$HOT_PILLOW")
confere "acende" "$(campo "$saida" class)" "active"
confere_contem "mostra 80°" "$(campo "$saida" text)" "80°"
confere "uma notificação" "$(contar_notificacoes)" "1"
confere "contador = 1" "$("$HOT_PILLOW" alertas | jq -r .text | grep -o '[0-9]* ALERTA!')" "1 ALERTA!"

echo "Continua quente: não repete o aviso"
"$HOT_PILLOW" > /dev/null
"$HOT_PILLOW" > /dev/null
confere "ainda uma notificação" "$(contar_notificacoes)" "1"

echo "Esfriou só um pouco (72°C, acima do rearme de 70°C)"
mudar_temp hwmon0 72
saida=$("$HOT_PILLOW")
confere "apaga" "$(campo "$saida" class)" ""
mudar_temp hwmon0 80
"$HOT_PILLOW" > /dev/null
confere "voltou a 80°C sem novo aviso" "$(contar_notificacoes)" "1"

echo "Esfriou de verdade (65°C) e esquentou de novo"
mudar_temp hwmon0 65
"$HOT_PILLOW" > /dev/null
mudar_temp hwmon0 80
"$HOT_PILLOW" > /dev/null
confere "segunda notificação" "$(contar_notificacoes)" "2"
saida=$("$HOT_PILLOW" alertas)
confere "JSON válido (alertas)" "$(json_valido "$saida")" "sim"
confere_contem "contador = 2 (plural)" "$(campo "$saida" text)" "2 ALERTAS!"

echo "Zerar"
"$HOT_PILLOW" zerar
confere "alertas some (saída vazia)" "$("$HOT_PILLOW" alertas)" ""

echo "Limite configurado (ALERTA_TEMP=60, REARMAR_TEMP=55)"
limpar
criar_sensor hwmon0 k10temp 65
printf 'ALERTA_TEMP=60\nREARMAR_TEMP=55\n' > "$HOT_PILLOW_CONFIG"
saida=$("$HOT_PILLOW")
confere "65°C acende com limite 60" "$(campo "$saida" class)" "active"
confere_contem "dica mostra o limite" "$(campo "$saida" tooltip)" "Alerta em 60°C"

echo "Config inválida"
limpar
criar_sensor hwmon0 k10temp 50
echo 'ALERTA_TEMP=quente' > "$HOT_PILLOW_CONFIG"
saida=$("$HOT_PILLOW")
confere_contem "volta para 75°C" "$(campo "$saida" tooltip)" "Alerta em 75°C"
confere_contem "avisa na dica" "$(campo "$saida" tooltip)" "ALERTA_TEMP inválido"

echo "REARMAR_TEMP maior que ALERTA_TEMP"
limpar
criar_sensor hwmon0 k10temp 50
printf 'ALERTA_TEMP=70\nREARMAR_TEMP=80\n' > "$HOT_PILLOW_CONFIG"
saida=$("$HOT_PILLOW")
confere_contem "avisa na dica" "$(campo "$saida" tooltip)" "usando 65°C"

echo "Sem sensor"
limpar
mkdir -p "$HOT_PILLOW_SENSORES"
saida=$("$HOT_PILLOW")
confere "JSON válido" "$(json_valido "$saida")" "sim"
confere_contem "mostra ?" "$(campo "$saida" text)" "?"

echo "Intel (coretemp) e GPU"
limpar
criar_sensor hwmon0 acpitz 40
criar_sensor hwmon1 coretemp 55
criar_sensor hwmon2 amdgpu 47
saida=$("$HOT_PILLOW")
confere_contem "prefere coretemp ao acpitz" "$(campo "$saida" text)" "55°"
confere_contem "dica mostra GPU" "$(campo "$saida" tooltip)" "GPU: 47°C"

echo "Modo desconhecido"
"$HOT_PILLOW" bla > /dev/null 2>&1
confere "sai com erro" "$?" "1"

# ---------------------------------------------------------------------------

echo
echo "Passou: $passou  Falhou: $falhou"
(( falhou == 0 ))
