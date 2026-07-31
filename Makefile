TARGET ?= aquario-stv3000

.PHONY: all build fetch patch compile pack clean status help ttl menuconfig info sysupgrade

all: build

help:
	@echo "OpenWrt-Style Android Multi-Device ImageBuilder"
	@echo "Comandos:"
	@echo "  make menuconfig                    - Interface interativa (.config / Kconfig TUI)"
	@echo "  make info                          - Exibe informações do alvo e pacotes selecionados"
	@echo "  make sysupgrade                    - Gera apenas a imagem de atualização de boot/system"
	@echo "  make TARGET=<dispositivo> build    - Compila e empacota o firmware completo (.img)"
	@echo "  make TARGET=<dispositivo> fetch    - Baixa os repositórios upstream"
	@echo "  make TARGET=<dispositivo> patch    - Aplica os patches e overlays do dispositivo"
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

menuconfig:
	@./build/scripts/menuconfig.sh $(TARGET)

sysupgrade:
	@echo "Gerando pacote de atualização rápida sysupgrade para $(TARGET)..."
	@./build/scripts/01_build_kernel_boot.sh $(TARGET)
	@echo "Sysupgrade Boot Image pronto em out/$(TARGET)/boot-aquario-performance-v70-padded-16m.img"

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
