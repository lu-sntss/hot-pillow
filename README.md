# hot-pillow

Mostra a temperatura da CPU na barra do [Omarchy](https://omarchy.org) e avisa quando ela passa do limite que você escolher.

```
🌡 58°          ← normal
🔥 81°          ← passou do limite: acende + notificação
⚠ 2 ALERTAS!   ← quantas vezes esquentou (pisca; clique para zerar)
```

- **Na barra:** temperatura da CPU, atualizada a cada 5 segundos
- **Passando o mouse:** temperatura da CPU e da GPU, e o limite configurado
- **Clicando:** abre o `btop` para ver o que está pesando
- **Passou do limite:** o ícone vira 🔥, o widget acende e chega uma notificação (uma vez só, sem spam)
- **Ícones:** na barra eles vêm da Nerd Font que o Omarchy já usa (os emojis acima são só ilustração)
- **Contador de alertas:** fica piscando ao lado até você clicar nele, para você não perder um aviso enquanto estava longe do PC

## Por que esse nome?

Porque um dia o notebook ficou em cima de um travesseiro, esquentou e deu pau.

## Requisitos

- [Omarchy](https://omarchy.org) (a barra dele é onde o hot-pillow aparece)
- Um sensor de temperatura que o Linux reconheça. O hot-pillow procura, nesta ordem:
  - AMD Ryzen (`k10temp`, `zenpower`) — **testado em hardware real** (Ryzen 7 3700U)
  - Intel (`coretemp`)
  - Raspberry Pi e outros ARM (`cpu_thermal`)
  - Sensor genérico da placa-mãe (`acpitz`)

  Os outros foram testados só com sensores simulados. Se você testar num deles, me conte numa issue!

Para ver quais sensores o seu PC tem:

```bash
cat /sys/class/hwmon/*/name
```

## Instalar

```bash
git clone https://github.com/lu-sntss/hot-pillow.git
cd hot-pillow
./install.sh
```

O instalador:

1. copia o script para `~/.local/bin/hot-pillow`
2. cria a configuração em `~/.config/hot-pillow/config`
3. faz um backup do `~/.config/omarchy/shell.json` e coloca os widgets na barra

Pode rodar de novo sem medo: ele não duplica nada e não apaga a sua configuração.

## Configurar

Edite `~/.config/hot-pillow/config`:

```bash
# A partir de quantos graus (°C) a CPU está "quente"
ALERTA_TEMP=75

# Depois de um alerta, só avisa de novo quando esfriar abaixo disto
REARMAR_TEMP=70
```

A mudança vale em alguns segundos, sem reiniciar nada. Se você colocar um valor inválido, o hot-pillow usa o padrão e avisa na dica (passando o mouse).

**Por que existe o `REARMAR_TEMP`?** Sem ele, se a CPU ficasse oscilando entre 74°C e 76°C, você receberia uma notificação a cada poucos segundos. Com ele, depois de um aviso, a CPU precisa esfriar de verdade antes de poder avisar de novo.

Futuramente pensando sobre fazer configuração via GUI no modal da barra de tarefas ;b

## Desinstalar

```bash
./uninstall.sh
```

Tira os widgets da barra (com backup antes) e apaga o script. A configuração fica guardada; o desinstalador mostra como apagar se quiser.

## Comandos

```bash
hot-pillow            # mostra a temperatura (é o que a barra roda)
hot-pillow alertas    # mostra o contador de alertas
hot-pillow zerar      # zera o contador
hot-pillow ajuda      # ajuda
```

## Testes

```bash
./tests/run.sh          # testa o hot-pillow com sensores "de mentira"
./tests/instalacao.sh   # testa install.sh e uninstall.sh numa home de mentira
```

Nenhum dos dois mexe no seu sistema de verdade.

## Como funciona

O Linux mostra os sensores de temperatura como arquivos em `/sys/class/hwmon/`. Cada sensor tem um arquivo `name` (o nome dele) e um `temp1_input` (a temperatura em milésimos de grau: `48000` = 48°C). O hot-pillow procura o primeiro sensor de CPU conhecido, lê esse número e imprime um JSON que a barra do Omarchy entende:

```json
{"text": "<ícone> 58°", "tooltip": "CPU: 58°C\nAlerta em 75°C"}
```

Quando passa do limite, o JSON ganha `"class": "active"`, que faz a barra destacar o widget.

É um único script em Bash, comentado, para ser fácil de ler e modificar.

## Licença

[MIT](LICENSE) © lu-sntss
