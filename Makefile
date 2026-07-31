TARGET ?= aquario-stv3000

.PHONY: all build fetch patch compile pack clean status help ttl

all: build

help:
	@echo "Sistema de Build Multi-Dispositivo Android"
	@echo "Uso:"
	@echo "  make TARGET=<dispositivo> build    - Compila e empacota o firmware completo"
	@echo "  make TARGET=<dispositivo> fetch    - Baixa os repositórios upstream"
	@echo "  make TARGET=<dispositivo> patch    - Aplica os patches e overlays do dispositivo"
	@echo "  make TARGET=<dispositivo> compile  - Executa a compilação no container Docker"
	@echo "  make TARGET=<dispositivo> clean    - Limpa artefatos gerados em out/"
	@echo "  make ttl                           - Abre conexão interativa serial TTL"
	@echo ""
	@echo "Dispositivos disponíveis em devices/:"
	@ls -1 devices/

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
