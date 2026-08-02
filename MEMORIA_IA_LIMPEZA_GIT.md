# Memória da IA - Limpeza de Histórico Git (Arquivos Grandes Recompiláveis e Baixáveis)

Data de Execução: 2026-08-02

## 🎯 Objetivo
Limpar o histórico do repositório Git removendo arquivos binários grandes que:
1. Podem ser **recompilados / gerados** diretamente pelo código-fonte e scripts de build deste repositório (Kernel, U-Boot, DTBs, `system-permanent.img`, `boot.img`).
2. Podem ser **facilmente baixados da internet** ou mantidos em cache/repositório de ativos externo (APKs pré-compilados de Chrome, Globoplay, YouTubeTV, Prime Video, Aurora Store).

---

## 📋 Lista de Arquivos Expurgados do Histórico Git

### 1. Imagens de Partição e Boot (Recompiláveis pelo pipeline)
- `target/linux/amlogic/s905w/aquario-stv3000/prebuilts/system-permanent.img` (1,81 GB)
- `target/linux/amlogic/s905w/aquario-stv3000/prebuilts/boot-aquario-performance-v69-padded-16m.img` (16,0 MB)

### 2. Binários de Baixo Nível / Kernel / U-Boot / DTBs (Recompiláveis pelo código)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/kernel` (6,8 MB)
- `devices/aquario-stv3000/overlay/device/aquario/stv3000/kernel` (6,8 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/prebuilts/uboot-gxl_p281_v1.bin` (4,0 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/prebuilts/aquario-performance-v69.dtb` (57,6 KB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/aquario.dtb` (42,1 KB)

### 3. APKs Pré-compilados de Terceiros (Baixáveis da Internet)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Chrome/base.apk` (105,5 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Chrome/split_chrome.apk` (3,1 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Chrome/split_google3.apk` (3,0 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Chrome/split_config.pt.apk` (885 KB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Chrome/split_config.en.apk` (266 KB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Globoplay/base.apk` (41,4 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Globoplay/config.tvdpi.apk` (1,6 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Globoplay/config.armeabi_v7a.apk` (1,0 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/Globoplay/config.pt.apk` (98 KB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/YouTubeTV/split_config.armeabi_v7a.apk` (37,4 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/YouTubeTV/base.apk` (5,4 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/PrimeVideo/config.armeabi_v7a.apk` (16,8 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/PrimeVideo/base.apk` (3,0 MB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/PrimeVideo/config.xhdpi.apk` (53 KB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/PrimeVideo/config.en.apk` (33 KB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/PrimeVideo/config.pt.apk` (25 KB)
- `target/linux/amlogic/s905w/aquario-stv3000/overlay/device/aquario/stv3000/prebuilts/apps/AuroraStore/base.apk` (6,7 MB)

---

## 🛠️ Passo a Passo Executado

1. **[X] Diagnóstico Inicial**: Mapeamento dos blobs grandes e histórico do Git.
2. **[X] Atualizar `.gitignore`**:
   - Bloqueado rastreamento automático de `.img`, `.bin`, `.dtb`, `.apk`.
   - Adicionado o diretório `scratch/` e os alvos de compilação do Rust (`build/tools/ampack/target/`).
3. **[X] Filtro do Histórico Git (`git-filter-repo`)**:
   - Reescreveu todo o histórico removendo todos os arquivos recompiláveis/baixáveis (tanto em caminhos atuais quanto em caminhos antigos).
4. **[X] Coleta de Lixo Agressiva (`git gc`)**:
   - Executado `git reflog expire --expire=now --all` e `git gc --prune=now --aggressive`.
5. **[X] Validação de Integridade**:
   - Todo o histórico de código, scripts, patches, Makefiles e documentação permaneceu intacto.

---

## 📈 Resultados Alcançados
- **Tamanho do Repositório Git (`.git`) Antes**: `825 MB`
- **Tamanho do Repositório Git (`.git`) Depois**: `2,5 MB`
- **Redução do Histórico**: **~99,7% de economia de espaço!**
