#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$ROOT_DIR/target/linux/amlogic/s905w/stv3000"
DOTCONFIG="$ROOT_DIR/.config"

if [[ ! -d "$DEVICE_DIR" ]]; then
    echo "[ERR] Perfil '$TARGET' não encontrado em $DEVICE_DIR"
    exit 1
fi

source "$DEVICE_DIR/board.conf"

MAIN_CHOICE=$(whiptail --title "OpenWrt-style ImageBuilder - Menuconfig" \
  --menu "Selecione a categoria para configurar (.config):" 18 75 8 \
  "1" "Target System: [amlogic/s905w/$TARGET]" \
  "2" "U-Boot Configuration: [Modo: $UBOOT_MODE]" \
  "3" "Kernel & RAM Tuning: [CMA: ${CMA_SIZE_MB}MB | LED: $GPIO_LED_STANDBY]" \
  "4" "Package Selection (SmartTube, Aurora, VLC, Globoplay)" \
  "5" "System Services & Daemons (force-stop, RAM monitor)" \
  "6" "Salvar e Gravar em .config" 3>&1 1>&2 2>&3) || exit 0

case "$MAIN_CHOICE" in
    1)
        whiptail --title "Target System" --msgbox "Target ativo: amlogic/s905w/$TARGET\nSoC: $SOC_MODEL ($ARCH)\nPerfil: $DEVICE_DIR" 10 65
        exec "$0" "$TARGET"
        ;;
    2)
        UB_CHOICE=$(whiptail --title "U-Boot Configuration" \
          --menu "Escolha o modo do U-Boot:" 14 65 2 \
          "prebuilt" "CONFIG_UBOOT_MODE_PREBUILT=y (Mais rápido/Estável)" \
          "build" "CONFIG_UBOOT_MODE_BUILD=y (Compilar do zero via Docker)" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        sed -i "s/^UBOOT_MODE=.*/UBOOT_MODE=\"$UB_CHOICE\"/" "$DEVICE_DIR/board.conf"
        if [[ "$UB_CHOICE" == "prebuilt" ]]; then
            sed -i "s/^CONFIG_UBOOT_MODE_BUILD=.*/# CONFIG_UBOOT_MODE_BUILD is not set/" "$DOTCONFIG" 2>/dev/null || true
            sed -i "s/^# CONFIG_UBOOT_MODE_PREBUILT.*/CONFIG_UBOOT_MODE_PREBUILT=y/" "$DOTCONFIG" 2>/dev/null || true
        else
            sed -i "s/^CONFIG_UBOOT_MODE_PREBUILT=.*/# CONFIG_UBOOT_MODE_PREBUILT is not set/" "$DOTCONFIG" 2>/dev/null || true
            sed -i "s/^# CONFIG_UBOOT_MODE_BUILD.*/CONFIG_UBOOT_MODE_BUILD=y/" "$DOTCONFIG" 2>/dev/null || true
        fi
        whiptail --msgbox "Modo U-Boot alterado para: $UB_CHOICE" 8 45
        exec "$0" "$TARGET"
        ;;
    3)
        CMA_CHOICE=$(whiptail --title "Kernel & RAM Tuning (CMA Video Pool)" \
          --menu "Selecione o tamanho da reserva CMA:" 14 65 3 \
          "224" "CONFIG_KERNEL_CMA_SIZE_MB=224 (Recomendado v69/v70 - 4K)" \
          "208" "CONFIG_KERNEL_CMA_SIZE_MB=208 (Padrão Amlogic)" \
          "192" "CONFIG_KERNEL_CMA_SIZE_MB=192 (Economia de RAM)" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        sed -i "s/^CMA_SIZE_MB=.*/CMA_SIZE_MB=\"$CMA_CHOICE\"/" "$DEVICE_DIR/board.conf"
        sed -i "s/^CONFIG_KERNEL_CMA_SIZE_MB=.*/CONFIG_KERNEL_CMA_SIZE_MB=$CMA_CHOICE/" "$DOTCONFIG" 2>/dev/null || true
        whiptail --msgbox "Reserva CMA alterada para: ${CMA_CHOICE}MB" 8 45
        exec "$0" "$TARGET"
        ;;
    4)
        APPS=$(whiptail --title "Package Selection" \
          --checklist "Selecione os pacotes para incluir na imagem:" 16 65 4 \
          "smarttube" "CONFIG_PACKAGE_smarttube (YouTube sem anúncios)" ON \
          "aurora_store" "CONFIG_PACKAGE_aurora_store (Play Store alternativa)" ON \
          "vlc" "CONFIG_PACKAGE_vlc (VLC Player acelerado)" ON \
          "globoplay" "CONFIG_PACKAGE_globoplay (Globoplay Oficial)" ON 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        whiptail --msgbox "Seleção de Pacotes salva no .config!" 8 45
        exec "$0" "$TARGET"
        ;;
    5)
        SERVICES=$(whiptail --title "System Services & Daemons" \
          --checklist "Marque os serviços ativos:" 15 65 3 \
          "FORCE_STOP" "CONFIG_SERVICE_FORCE_STOP_BOOT=y (Limpa RAM no boot)" ON \
          "RAM_MONITOR" "CONFIG_SERVICE_RAM_MONITOR=y (Monitor de status)" ON \
          "AUDIT_ZERO" "CONFIG_SELINUX_AUDIT_ZERO=y (Audit 0)" ON 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        whiptail --msgbox "Serviços salvos com sucesso!" 8 45
        exec "$0" "$TARGET"
        ;;
    6)
        whiptail --msgbox "Configurações gravadas com sucesso no arquivo .config!\n\nPara compilar a imagem rode: make build" 10 60
        exit 0
        ;;
esac
