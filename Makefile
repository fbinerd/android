TARGET ?= aquario-stv3000

.PHONY: all build fetch patch compile pack clean status help ttl menuconfig info sysupgrade feeds flash-sd flash-adb

all: build

help:
	@echo "OpenWrt-Style Android Multi-Device ImageBuilder"
	@echo "Comandos:"
	@echo "  make menuconfig                    - Interface interativa (.config / Kconfig TUI)"
	@echo "  make info                          - Exibe informações do alvo e pacotes selecionados"
	@echo "  make sysupgrade                    - Gera apenas a imagem de atualização de boot/system"
	@echo "  make feeds                         - Lista todos os pacotes de aplicativos/serviços"
	@echo "  make TARGET=<dispositivo> build    - Compila e empacota o firmware completo (.img)"
	@echo "  make flash-sd DEV=/dev/sdX         - Grava a imagem gerada no Cartão SD informado"
	@echo "  make flash-adb IP=192.168.1.139    - Envia a imagem de boot/update via ADB para a TV Box"
	@echo "  make TARGET=<dispositivo> compile  - Executa a compilação no container Docker"
	@echo "  make TARGET=<dispositivo> clean    - Limpa artefatos gerados em out/"
	@echo "  make ttl                           - Abre conexão interativa serial TTL"
	@echo ""
	@echo "Dispositivos disponíveis em target/linux/:"
	@ls -1 target/linux/amlogic/s905w/

info:
	@echo "=========================================================="
	@echo "   OPENWRT-STYLE BUILD SUMMARY FOR $(TARGET)"
	@echo "=========================================================="
	@cat .config 2>/dev/null || true
	@echo "=========================================================="

feeds:
	@./scripts/feeds list

menuconfig:
	@./build/scripts/menuconfig.sh $(TARGET)

sysupgrade:
	@echo "Gerando pacote de atualização rápida sysupgrade para $(TARGET)..."
	@./build/scripts/01_build_kernel_boot.sh $(TARGET)
	@echo "Sysupgrade Boot Image pronto em out/$(TARGET)/boot-aquario-performance-v70-padded-16m.img"

flash-sd:
	@if [ -z "$(DEV)" ]; then echo "ERRO: Especifique o dispositivo SD. Ex: make flash-sd DEV=/dev/sdX"; exit 1; fi
	@echo "ATENÇÃO: Gravando imagem em $(DEV)..."
	@sudo dd if=out/$(TARGET)/$(TARGET)-android9-v70-full-factory.img of=$(DEV) bs=4M status=progress conv=fsync
	@echo "Gravação no Cartão SD concluída com sucesso!"

flash-adb:
	@IP_BOX=$${IP:-192.168.1.139}; \
	echo "Enviando imagem de boot v70 para a TV Box no IP $$IP_BOX via ADB/SSH..."; \
	scp out/$(TARGET)/boot-aquario-performance-v70-padded-16m.img root@$$IP_BOX:/data/local/tmp/

fetch:
	@./build.sh $(TARGET) fetch

patch:
	@./build.sh $(TARGET) patch

compile:
	@./build.sh $(TARGET) compile

pack:
	@./build.sh $(TARGET) pack

build:
	@./build.sh $(TARGET) build

clean:
	@./build.sh $(TARGET) clean

ttl:
	@cd recovery/serial && ./conectar_ttl.sh --reset
