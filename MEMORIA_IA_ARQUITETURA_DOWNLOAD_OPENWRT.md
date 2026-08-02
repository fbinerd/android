# Memória da IA - Arquitetura de Build, Download On-Demand e Reuso OpenWrt

Data de Registro: 2026-08-02

## 📌 Resumo Executivo
Esta memória documenta as decisões de arquitetura de build, gerenciamento de histórico do Git, preservação de blobs essenciais de hardware, o design do sistema `make download` estilo OpenWrt e as ferramentas oficiais do OpenWrt integradas ao projeto.

---

## 🧹 1. Limpeza do Histórico Git e Redução de Tamanho
* **Diagnóstico Inicial**: Repositório Git acumulava **825 MB** na pasta `.git` e **~2,08 GB** de binários descomprimidos no histórico devido ao commit acidental de imagens brutas de sistema (`system-permanent.img` de 1,81 GB) e APKs grandes de terceiros (~230 MB).
* **Expurgo Histórico**:
  * Executado `git-filter-repo` expurgando arquivos recompiláveis/baixáveis (`system-permanent.img`, `boot-*.img`, `uboot-gxl_p281_v1.bin`, `kernel`, `*.dtb` e APKs de terceiros).
  * Executada coleta de lixo agressiva com `git reflog expire --expire=now --all` e `git gc --prune=now --aggressive`.
* **Resultado**: A pasta `.git` foi reduzida de **825 MB para 2,5 MB** (economia de **~99,7%**).
* **Sincronização Remote**:
  * Branch local renomeada de `master` para `main` (`git branch -M main`).
  * Remoto configurado para `https://github.com/fbinerd/android.git`.
  * Código limpo enviado com sucesso para `origin/main`.

---

## 🛡️ 2. Preservação de Blobs Proprietários Essenciais de Hardware
Para garantir que o compilador funcione **out-of-the-box** em qualquer máquina clonada sem dependência externa, os binários proprietários de baixo nível (~13 MB total) foram mantidos e commitados:

1. **Bootloader Estágio 1/2 Amlogic**: `bootloader-sd-loading-v53-4m.bin` *(4,0 MB)* — contém BL30/BL31/BL2 fechados e assinados da fábrica Amlogic.
2. **Ramdisk Base v70**: `ramdisk-base-v70.img` *(6,15 MB)* — ramdisk stock com daemons de inicialização.
3. **Módulos de Kernel Proprietários (`.ko`)**:
   * `mali.ko` (GPU Mali-450)
   * `ssv6051.ko`, `ssv6x5x.ko`, `ssv_hwif_ctrl.ko` (Wi-Fi South Silicon SV6051)
   * `mac80211.ko`
4. **Overlay de GMS / Sistema Base**: APKs de suporte e estruturas (`GoogleServicesFramework`, `PrebuiltGmsCorePano`, `TVLauncher`, `LatinIMEGoogleTv`).

---

## 🌐 3. Arquitetura `make download` (Estilo OpenWrt Builder)

### Lógica de Funcionamento
1. **Diretório Cache `dl/`**: Diretório não rastreado no Git usado como cache central de downloads. O download é feito uma única vez e reaproveitado em compilações subsequentes.
2. **Download On-Demand de APKs (Play Store / Aurora API)**:
   * Em vez de URLs estáticas sujeitas a 404, o script `scripts/fetch_apk.py` utiliza a API pública da Google Play / Aurora Store ou APKMirror.
   * O usuário seleciona ou digita o **Package ID** no `make menuconfig` (ex: `com.android.chrome`, `com.globo.globotv`).
   * O `make download` obtém os APKs oficiais mais recentes e resolve automaticamente os splits de arquitetura ARMv7 para a SoC S905W.

### Componentes Não-APK Baixados via `make download`
1. **Cross-Toolchain GCC / Clang ARM**: Compiladores C/C++ (`gcc-linaro-arm-linux-gnueabihf`) (~250-500 MB).
2. **Código-Fonte Bruto do Kernel Linux**: Tarball oficial Amlogic 3.14 / Linux kernel (~150-300 MB).
3. **Código-Fonte Bruto do U-Boot GXL**: Tarball do U-Boot upstream (~30-80 MB).
4. **Ferramentas Host de Empacotamento**: `mkbootimg`, `dtc`, `img2simg`, `simg2img`, `mksquashfs`.
5. **Assets Estáticos**: Imagens de splash/handoff HDMI (`logo.img`).

---

## 🛠️ 4. Reaproveitamento de Ferramentas Oficiais do OpenWrt

O projeto adota 7 ferramentas/padrões consagrados do ecossistema OpenWrt:

1. **`scripts/download.pl` / `scripts/download.sh`**: Sistema de download com resiliência a falhas, lista de mirrors (espelhos) e verificação de integridade SHA256.
2. **`ptgen` (Partition Table Generator)**: Utilitário leve em C que gera tabelas de partição MBR/GPT diretamente em arquivos `.img` com precisão de byte, sem requerer `sudo` ou privilégios de root.
3. **`scripts/patch-kernel.sh`**: Sistema automatizado de aplicação sequencial de patches (`0001-...patch`, `0002-...patch`) com checagem de erros de rejeição (`.rej`).
4. **`scripts/feeds`**: Script de gerenciamento e instalação de pacotes de aplicativos/serviços adicionais (`package/apps/` e `package/services/`).
5. **Gerenciador Kconfig (`mconf` / `.config`)**: Sintaxe padrão `CONFIG_TARGET_...=y`, `CONFIG_PACKAGE_...=y`.
6. **Macros de Pacotes (`include/package.mk`)**: Estrutura modular de Makefiles por aplicativo em `package/apps/<nome>/Makefile`.
7. **`ImageBuilder`**: Separação clara entre a fase de compilação bruta do C++ e a fase de montagem/empacotamento rápido do firmware final (`.img`).
