#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"
DOTCONFIG="$ROOT_DIR/.config"

if [[ -z "$DEVICE_DIR" || ! -d "$DEVICE_DIR" ]]; then
    echo "[ERR] Perfil '$TARGET' não encontrado em target/linux/"
    exit 1
fi

source "$DEVICE_DIR/board.conf"

FLASH_SIZE_GB="${FLASH_SIZE_GB:-8g}"
STORAGE_MEDIUM="${STORAGE_MEDIUM:-emmc}"
SWAP_TYPE="${SWAP_TYPE:-zram_256m}"

MAIN_CHOICE=$(whiptail --title "OpenWrt-style ImageBuilder - Menuconfig" \
  --menu "Selecione a categoria para configurar (.config):" 20 78 9 \
  "1" "Target System: [amlogic/s905w/$TARGET]" \
  "2" "Flash Layout & Storage: [Size: $FLASH_SIZE_GB | Media: $STORAGE_MEDIUM | Swap: $SWAP_TYPE]" \
  "3" "U-Boot Configuration: [Modo: $UBOOT_MODE]" \
  "4" "Kernel & RAM Tuning: [CMA: ${CMA_SIZE_MB}MB | LED: $GPIO_LED_STANDBY]" \
  "5" "Package Selection (SmartTube, Aurora, VLC, Globoplay)" \
  "6" "System Services & Daemons (force-stop, RAM monitor)" \
  "7" "Salvar e Gravar em .config" 3>&1 1>&2 2>&3) || exit 0

case "$MAIN_CHOICE" in
    1)
        whiptail --title "Target System" --msgbox "Target ativo: amlogic/s905w/$TARGET\nSoC: $SOC_MODEL ($ARCH)\nPerfil: $DEVICE_DIR" 10 65
        exec "$0" "$TARGET"
        ;;
    2)
        SIZE_CHOICE=$(whiptail --title "Preset de Tamanho de Armazenamento" \
          --menu "Selecione a capacidade da memória Flash de destino:" 15 65 3 \
          "8g" "8 GB Flash (Padrão eMMC / Cartão SD)" \
          "16g" "16 GB Flash (Mais espaço para apps e cache)" \
          "32g" "32 GB Flash (Capacidade máxima para mídias)" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        MEDIA_CHOICE=$(whiptail --title "Tipo de Mídia de Armazenamento" \
          --menu "Selecione a mídia de boot de destino:" 15 65 3 \
          "emmc" "eMMC Flash Interna (Memória onboard)" \
          "sdcard" "Cartão MicroSD Externo Bootável" \
          "nand" "Legacy RAW NAND Flash" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"

        SWAP_CHOICE=$(whiptail --title "Configuração de Memória Swap / ZRAM" \
          --menu "Selecione o tipo de Swap:" 16 68 4 \
          "zram_256m" "ZRAM 256 MB em RAM (Recomendado 1GB RAM)" \
          "zram_512m" "ZRAM 512 MB em RAM" \
          "partition" "Partição de Swap Dedicada no Disco (512MB)" \
          "none" "Sem Swap" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"

        sed -i "s/^FLASH_SIZE_GB=.*/FLASH_SIZE_GB=\"$SIZE_CHOICE\"/" "$DEVICE_DIR/board.conf"
        sed -i "s/^STORAGE_MEDIUM=.*/STORAGE_MEDIUM=\"$MEDIA_CHOICE\"/" "$DEVICE_DIR/board.conf"
        sed -i "s/^SWAP_TYPE=.*/SWAP_TYPE=\"$SWAP_CHOICE\"/" "$DEVICE_DIR/board.conf"
        
        sed -i "s/^CONFIG_FLASH_SIZE=.*/CONFIG_FLASH_SIZE=\"$SIZE_CHOICE\"/" "$DOTCONFIG" 2>/dev/null || echo "CONFIG_FLASH_SIZE=\"$SIZE_CHOICE\"" >> "$DOTCONFIG"
        sed -i "s/^CONFIG_STORAGE_MEDIUM=.*/CONFIG_STORAGE_MEDIUM=\"$MEDIA_CHOICE\"/" "$DOTCONFIG" 2>/dev/null || echo "CONFIG_STORAGE_MEDIUM=\"$MEDIA_CHOICE\"" >> "$DOTCONFIG"
        sed -i "s/^CONFIG_SWAP_TYPE=.*/CONFIG_SWAP_TYPE=\"$SWAP_CHOICE\"/" "$DOTCONFIG" 2>/dev/null || echo "CONFIG_SWAP_TYPE=\"$SWAP_CHOICE\"" >> "$DOTCONFIG"

        whiptail --msgbox "Configuração de Armazenamento Salva:\n- Tamanho: $SIZE_CHOICE\n- Mídia: $MEDIA_CHOICE\n- Swap: $SWAP_CHOICE" 10 50
        exec "$0" "$TARGET"
        ;;
    3)
        UB_CHOICE=$(whiptail --title "U-Boot Configuration" \
          --menu "Escolha o modo do U-Boot:" 14 65 2 \
          "prebuilt" "CONFIG_UBOOT_MODE_PREBUILT=y (Mais rápido/Estável)" \
          "build" "CONFIG_UBOOT_MODE_BUILD=y (Compilar do zero via Docker)" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        sed -i "s/^UBOOT_MODE=.*/UBOOT_MODE=\"$UB_CHOICE\"/" "$DEVICE_DIR/board.conf"
        whiptail --msgbox "Modo U-Boot alterado para: $UB_CHOICE" 8 45
        exec "$0" "$TARGET"
        ;;
    4)
        CMA_CHOICE=$(whiptail --title "Kernel & RAM Tuning (CMA Video Pool)" \
          --menu "Selecione o tamanho da reserva CMA:" 14 65 3 \
          "224" "CONFIG_KERNEL_CMA_SIZE_MB=224 (Recomendado v69/v70 - 4K)" \
          "208" "CONFIG_KERNEL_CMA_SIZE_MB=208 (Padrão Amlogic)" \
          "192" "CONFIG_KERNEL_CMA_SIZE_MB=192 (Economia de RAM)" 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        sed -i "s/^CMA_SIZE_MB=.*/CMA_SIZE_MB=\"$CMA_CHOICE\"/" "$DEVICE_DIR/board.conf"
        whiptail --msgbox "Reserva CMA alterada para: ${CMA_CHOICE}MB" 8 45
        exec "$0" "$TARGET"
        ;;
    5)
        APPS=$(whiptail --title "Package Selection" \
          --checklist "Selecione os pacotes para incluir na imagem:" 16 65 4 \
          "smarttube" "CONFIG_PACKAGE_smarttube (YouTube sem anúncios)" ON \
          "aurora_store" "CONFIG_PACKAGE_aurora_store (Play Store alternativa)" ON \
          "vlc" "CONFIG_PACKAGE_vlc (VLC Player acelerado)" ON \
          "globoplay" "CONFIG_PACKAGE_globoplay (Globoplay Oficial)" ON 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        whiptail --msgbox "Seleção de Pacotes salva no .config!" 8 45
        exec "$0" "$TARGET"
        ;;
    6)
        SERVICES=$(whiptail --title "System Services & Daemons" \
          --checklist "Marque os serviços ativos:" 15 65 3 \
          "FORCE_STOP" "CONFIG_SERVICE_FORCE_STOP_BOOT=y (Limpa RAM no boot)" ON \
          "RAM_MONITOR" "CONFIG_SERVICE_RAM_MONITOR=y (Monitor de status)" ON \
          "AUDIT_ZERO" "CONFIG_SELINUX_AUDIT_ZERO=y (Audit 0)" ON 3>&1 1>&2 2>&3) || exec "$0" "$TARGET"
        
        whiptail --msgbox "Serviços salvos com sucesso!" 8 45
        exec "$0" "$TARGET"
        ;;
    7)
        whiptail --msgbox "Configurações gravadas com sucesso no arquivo .config!\n\nPara compilar a imagem rode: make build" 10 60
        exit 0
        ;;
esac
