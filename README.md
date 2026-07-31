# 🚀 Android Multi-Device Build System (`android-multi-builder`)

Sistema de compilação modular, containerizado e baseado em **Patches & Overlays** para TV Boxes e dispositivos embarcados (Amlogic S905W, Rockchip, Allwinner).

---

## 🎯 Dispositivos Suportados (`devices/`)

- **Aquário STV3000** (`aquario-stv3000`): Amlogic S905W, Android 9 AOSP, Kernel 4.9.113, CMA 224MB, Standby LED `GPIODV_24` (GPIO 474), Boot SD Autônomo v62/v70.

---

## 📂 Arquitetura do Repositório

```text
android-multi-builder/
├── README.md                           # Guia do sistema de build
├── MEMORIA_IA.md                       # Histórico técnico contínuo de revisões (v62 a v70)
├── Makefile                            # Comandos unificados (make TARGET=aquario-stv3000 build)
├── build.sh                            # Script CLI mestre de automação
│
├── build/                              # 🛠️ Automação de Build e Ferramentas Nativas
│   ├── docker/                         # Containers de build isolados
│   ├── scripts/                        # Pipeline de integração
│   └── tools/                          # Ferramentas nativas (ampack, ampart, aml_lz4c)
│
├── common/                             # 🌐 Patches e Pacotes Compartilhados
│   ├── patches/                        # Patches genéricos por SoC ou Android
│   └── packages/                       # Daemons e utilitários globais
│
├── devices/                            # 🎯 Perfis Específicos por Dispositivo
│   └── aquario-stv3000/                # Perfil da TV Box Aquário STV3000
│       ├── board.conf                  # Definições de hardware e sistema
│       ├── configs/                    # DTS, defconfigs, ept.json
│       ├── patches/                    # Patches exclusivos (Kernel, U-Boot, AOSP)
│       ├── overlay/                    # Sobrescritas (/system, /vendor, /odm)
│       └── assets/                     # Logos e animação de boot (v63)
│
├── recovery/                           # 🚑 Resgate e Debug Serial TTL
│   └── serial/                         # Script conectar_ttl.sh e broker TCP (porta 31337)
│
├── workspace/                          # 📂 Fontes clonadas dinamicamente (.gitignore)
└── out/                                # 🚀 Imagens e firmwares gerados (.gitignore)
```

---

## ⚙️ Uso Rápido

### 1. Compilar o Firmware Completo
```bash
make TARGET=aquario-stv3000 build
# ou
./build.sh aquario-stv3000 build
```

### 2. Conectar na Serial TTL para Debug
```bash
make ttl
# ou
cd recovery/serial && ./conectar_ttl.sh --reset
```

### 3. Limpar Artefatos de Build
```bash
make TARGET=aquario-stv3000 clean
```
