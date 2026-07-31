#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$ROOT_DIR/devices/$TARGET"

if [[ ! -d "$DEVICE_DIR" ]]; then
    echo "[ERR] Perfil '$TARGET' não encontrado em $DEVICE_DIR"
    exit 1
fi

source "$DEVICE_DIR/board.conf"

USER_CONF="$DEVICE_DIR/configs/user_features.conf"
mkdir -p "$DEVICE_DIR/configs"

# Valores padrão se não existirem
ENABLE_SMARTTUBE="${ENABLE_SMARTTUBE:-1}"
ENABLE_AURORA="${ENABLE_AURORA:-1}"
ENABLE_VLC="${ENABLE_VLC:-1}"
ENABLE_GLOBOPLAY="${ENABLE_GLOBOPLAY:-1}"
ENABLE_FORCE_STOP="${ENABLE_FORCE_STOP:-1}"
ENABLE_RAM_MONITOR="${ENABLE_RAM_MONITOR:-1}"

if [[ -f "$USER_CONF" ]]; then
    source "$USER_CONF"
fi

MAIN_CHOICE=$(whiptail --title "Android Multi-Device Builder - Menuconfig" \
  --menu "Selecione a categoria para configurar:" 18 75 8 \
  "1" "Target Board: [$BOARD_NAME]" \
  "2" "U-Boot & Bootloader: [Modo: $UBOOT_MODE]" \
  "3" "Kernel & RAM Tuning: [CMA: ${CMA_SIZE_MB}MB | LED: $GPIO_LED_STANDBY]" \
  "4" "Aplicativos Integrados (SmartTube, Aurora, VLC)" \
  "5" "Serviços & Daemons de Boot" \
  "6" "Salvar e Sair" 3>&1 1>&2 2>&3) || exit 0

case "$MAIN_CHOICE" in
    1)
        whiptail --title "Dispositivos Suportados" --msgbox "Dispositivo ativo: $BOARD_NAME ($SOC_MODEL / $ARCH)\n\nPerfil localizado em: devices/$TARGET/" 10 65
        exec "$0" "$TARGET"
        ;;
    2)
        UB_CHOICE=$(whiptail --title "Configuração do U-Boot" \
          --menu "Escolha o modo do U-Boot:" 14 65 2 \
          "prebuilt" "Usar binário FIP pré-compilado (Mais rápido/Estável)" \
          "build" "Compilar U-Boot do zero a partir do código C no Docker" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        sed -i "s/^UBOOT_MODE=.*/UBOOT_MODE=\"$UB_CHOICE\"/" "$DEVICE_DIR/board.conf"
        whiptail --msgbox "Modo U-Boot alterado para: $UB_CHOICE" 8 45
        exec "$0" "$TARGET"
        ;;
    3)
        CMA_CHOICE=$(whiptail --title "Ajuste de Memória CMA (Codec Video 4K)" \
          --menu "Selecione o tamanho da reserva de memória para vídeo 4K:" 14 65 3 \
          "224" "224 MB (Recomendado v69/v70 - Suporte total 4K HEVC)" \
          "208" "208 MB (Tamanho original Amlogic)" \
          "192" "192 MB (Economiza RAM para o sistema)" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        sed -i "s/^CMA_SIZE_MB=.*/CMA_SIZE_MB=\"$CMA_CHOICE\"/" "$DEVICE_DIR/board.conf"
        whiptail --msgbox "Reserva CMA alterada para: ${CMA_CHOICE}MB" 8 45
        exec "$0" "$TARGET"
        ;;
    4)
        APPS=$(whiptail --title "Seleção de Aplicativos Pré-Instalados" \
          --checklist "Marque os aplicativos que deseja incluir na partição /system:" 16 65 4 \
          "SMARTTUBE" "SmartTube Next (YouTube sem anúncios)" ON \
          "AURORA" "Aurora Store (Play Store alternativa)" ON \
          "VLC" "VLC Player (Player de vídeo com hardware acceleration)" ON \
          "GLOBOPLAY" "Globoplay Oficial" ON 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        [[ "$APPS" =~ "SMARTTUBE" ]] && ENABLE_SMARTTUBE=1 || ENABLE_SMARTTUBE=0
        [[ "$APPS" =~ "AURORA" ]] && ENABLE_AURORA=1 || ENABLE_AURORA=0
        [[ "$APPS" =~ "VLC" ]] && ENABLE_VLC=1 || ENABLE_VLC=0
        [[ "$APPS" =~ "GLOBOPLAY" ]] && ENABLE_GLOBOPLAY=1 || ENABLE_GLOBOPLAY=0

        cat <<EOF > "$USER_CONF"
ENABLE_SMARTTUBE=$ENABLE_SMARTTUBE
ENABLE_AURORA=$ENABLE_AURORA
ENABLE_VLC=$ENABLE_VLC
ENABLE_GLOBOPLAY=$ENABLE_GLOBOPLAY
ENABLE_FORCE_STOP=$ENABLE_FORCE_STOP
ENABLE_RAM_MONITOR=$ENABLE_RAM_MONITOR
EOF
        whiptail --msgbox "Seleção de Aplicativos salva com sucesso!" 8 45
        exec "$0" "$TARGET"
        ;;
    5)
        SERVICES=$(whiptail --title "Serviços e Otimizações de Boot" \
          --checklist "Marque os serviços ativos no boot:" 15 65 3 \
          "FORCE_STOP" "Force-stop automático em apps pesados no boot (Economiza RAM/IO)" ON \
          "RAM_MONITOR" "Monitor de CPU/RAM/GPU no launcher" ON \
          "AUDIT_ZERO" "Desativar flood de logs do SELinux (audit=0)" ON 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        whiptail --msgbox "Configurações de Serviços salvas com sucesso!" 8 45
        exec "$0" "$TARGET"
        ;;
    6)
        whiptail --msgbox "Configurações salvas em devices/$TARGET/board.conf!\n\nPara compilar com as novas escolhas, rode: make build" 10 60
        exit 0
        ;;
esac
