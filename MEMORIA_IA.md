# Memoria de trabalho IA - Firmware Lab Aquario STV-3000

Atualizado em: 2026-07-21

## Pedido atual

- Objetivo do usuario: abrir/analisar `aquario.img`, usar ferramentas e containers locais de engenharia reversa, e compilar uma nova imagem Android 9 para a TV Box Aquario STV-3000.
- Observacao importante do usuario: o material "Aidan" pode nao ter relacao direta com a imagem do Aquario; tratar `aquario.img` como fonte primaria e usar Aidan apenas como referencia/ferramenta quando fizer sentido.

## Caminhos importantes

- Workspace: `/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab`
- Imagem primaria Aquario: `infra/aidan/data/aquario.img`
- Saida esperada pelo script antigo: `infra/aidan/data/aquario_android9_custom.img`
- BSP extraido da imagem primaria: `infra/aidan/data/aquario_bsp`
- Particoes extraidas: `infra/aidan/data/aquario_bsp/particoes`
- AOSP 9 local: `infra/aidan/aosp9`
- Device tree AOSP local: `infra/aidan/aosp9/device/aquario/stv3000`
- Vendor local: `infra/aidan/aosp9/vendor/aquario/stv3000`
- Kernel Android/Pie Khadas: `work/khadas-linux-pie`
- Kernel build/output: `work/build-khadas-stv3000`
- Ferramenta EPT Amlogic: `infra/aidan/data/ampart/ampart`
- Script de build/pack antigo: `scripts/build-and-pack-aosp9-aquario.sh`

## Containeres

- Container AOSP ativo: `android9-aquario`
- Imagem Docker: `android9-aquario-builder:latest`
- Compose: `docker/compose.android9.yaml`
- Bind mount do lab no container: `/workspace/firmware-lab`
- Diretório de trabalho no container: `/workspace/firmware-lab/infra/aidan/aosp9`
- Outro container ativo: `recovery-lab-tftp-server-1`

## Fatos confirmados sobre `aquario.img`

- Arquivo: `infra/aidan/data/aquario.img`
- Tamanho: `7818182656` bytes, aproximadamente 7.3 GiB.
- `file` identifica como `data`; `ampart` identifica como dump de disco completo Amlogic.
- Android de fabrica identificado nas propriedades extraidas: Android `7.1.2`, fingerprint `Amlogic/p281/p281:7.1.2/STV-3000/20220608:userdebug/test-keys`.
- SoC/plataforma no DTB: `gxl_p281`, variantes `1g` e `2g`.
- DTBs extraidos do BSP em `infra/aidan/data/aquario_bsp/dtb/`, incluindo `aquario_2_offset_440800.dtb`.

## Layout EPT confirmado de `aquario.img`

Snapshot decimal:

```text
bootloader:0:4194304:0 reserved:37748736:67108864:0 cache:113246208:536870912:2 env:658505728:8388608:0 logo:675282944:33554432:1 recovery:717225984:33554432:1 rsv:759169024:8388608:1 tee:775946240:8388608:1 crypt:792723456:33554432:1 misc:834666496:33554432:1 boot:876609536:33554432:1 system:918552576:2147483648:1 data:3074424832:4743757824:4
```

Resumo humano:

```text
bootloader  offset 0 MiB    size 4 MiB
reserved    offset 36 MiB   size 64 MiB
cache       offset 108 MiB  size 512 MiB
env         offset 628 MiB  size 8 MiB
logo        offset 644 MiB  size 32 MiB
recovery    offset 684 MiB  size 32 MiB
rsv         offset 724 MiB  size 8 MiB
tee         offset 740 MiB  size 8 MiB
crypt       offset 756 MiB  size 32 MiB
misc        offset 796 MiB  size 32 MiB
boot        offset 836 MiB  size 32 MiB
system      offset 876 MiB  size 2 GiB
data        offset 2932 MiB size 4524 MiB
```

- Layout original nao tem particao `vendor`.
- Para Android 9 existem duas estrategias:
  - manter layout original e colocar vendor/conteudo proprietario dentro de `system`;
  - migrar EPT criando `vendor`, `odm`, `product`, `vbmeta` etc., como alguns scripts antigos tentam fazer.

## BSP extraido da imagem primaria

- Particoes extraidas em `infra/aidan/data/aquario_bsp/particoes`:
  - `boot.img` 32 MiB
  - `recovery.img` 32 MiB
  - `system.img` 2 GiB
  - `cache.img` 512 MiB
  - `data.img` aproximadamente 4.5 GiB
  - demais particoes Amlogic: `bootloader`, `reserved`, `env`, `logo`, `rsv`, `tee`, `crypt`, `misc`
- Boot extraido:
  - `aquario_bsp/boot/boot/kernel`: gzip compressed data, kernel original.
  - `aquario_bsp/boot/boot/ramdisk`: gzip compressed data.
  - `dt` e `second` aparecem vazios na extracao de boot.

## AOSP 9 atual

- Produto AOSP configurado: `aquario_stv3000`
- Device: `stv3000`
- `PRODUCT_OUT`: `out/target/product/stv3000`
- `TARGET_PREBUILT_KERNEL`: `device/aquario/stv3000/kernel`
- `BOARD_SYSTEMIMAGE_PARTITION_SIZE`: `1946157056`
- `BOARD_VENDORIMAGE_PARTITION_SIZE`: `536870912`
- Antes do build completo, existiam `boot.img`, `kernel`, `ramdisk.img` e arvore `system/` no `out`, mas nao `system.img`/`vendor.img`.
- Em 2026-07-21 foi iniciado build no container:

```bash
docker exec android9-aquario bash -lc 'cd /workspace/firmware-lab/infra/aidan/aosp9 && source build/envsetup.sh >/dev/null && lunch aquario_stv3000-userdebug && m -j$(nproc) bootimage systemimage vendorimage'
```

- O build avancou pelo menos ate aproximadamente 92% sem falhar; aguardar conclusao ou erro.
- Durante o build, `vendor.img` foi gerado em `out/target/product/stv3000/vendor.img`.
- Build AOSP 9 concluiu gerando:
  - `boot.img` 8,763,392 bytes
  - `recovery.img` 13,082,624 bytes
  - `system.img` sparse 699,781,364 bytes; raw 1,946,157,056 bytes
  - `vendor.img` sparse 39,170,220 bytes; raw 536,870,912 bytes
- Artefatos convertidos e divididos para TFTP em `work/tftp-aquario-android9-20260721-2`.
- TFTP recebeu:
  - `boot-a9.img`
  - `recovery-a9.img`
  - `a9ven.000`..`a9ven.007`
  - `a9sys.000`..`a9sys.028`

## Kernel

- Existe kernel 4.9/Pie Khadas em `work/khadas-linux-pie`.
- Saidas relevantes encontradas:
  - `work/build-khadas-stv3000/kernel-out/Image.gz-dtb-aquario-original`
  - `work/teste-khadas-stv3000/Image.gz`
  - varias imagens `Image.gz-dtb-*` em `work/teste-khadas-stv3000/imagens`
- AOSP atual usa kernel precompilado em `device/aquario/stv3000/kernel`.

## Cuidados

- Nao assumir que `aquario_aidan_final.img`, `aidanrom.img` ou particoes em `infra/aidan/data/extraido` correspondem ao firmware original Aquario.
- Preservar `aquario.img` original; gerar imagens novas por copia/reflink/sparse.
- Antes de gravar no eMMC real, validar offsets e tamanhos com `ampart --mode esnapshot` na imagem final.

## TTL / U-Boot / TFTP

- Script TTL usado: `../recovery-lab/conectar_ttl.sh`.
- Em 2026-07-21 o broker serial estava ativo em `/dev/ttyUSB1`, porta TCP local `31337`, processo `serial_broker.py broker`.
- Prompt U-Boot observado: `A95X#`.
- Versao U-Boot:

```text
U-Boot 2015.01 (Sep 21 2022 - 17:26:13)
```

- Variaveis de rede coletadas inicialmente no U-Boot:

```text
ipaddr=10.18.9.97
serverip=10.18.9.113
gatewayip=10.18.9.1
netmask=255.255.255.0
ethact=dwmac.c9410000
ethaddr=3c:e5:b4:20:09:35
```

- Variaveis relevantes:
  - `aml_dt=gxl_p281_1g`
  - `bootcmd=run storeboot`
  - `boot_part=boot`
  - `bootargs` usa `androidboot.hardware=amlogic`, `androidboot.selinux=permissive`, `androidboot.slot_suffix=_a`, `console=ttyAML0,115200`.
  - `storeboot=if imgread kernel ${boot_part} ${loadaddr}; then bootm ${loadaddr}; fi;run update;`
  - `recovery_from_udisk` tenta `aml_autoscript`, depois `recovery.img` e opcional `dtb.img` via USB FAT.
  - `recovery_from_sdcard` faz fluxo equivalente via SD.
- Comando TFTP disponivel: `tftpboot [loadAddress] [[hostIPaddr:]bootfilename]`.
- `bdinfo` nao existe neste U-Boot.
- Container TFTP ativo: `recovery-lab-tftp-server-1`, usando `dnsmasq --enable-tftp`.
- O TFTP estava servindo `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx` como `/var/tftpboot`.
- Usuario definiu rede de teste: Aquario/U-Boot em `192.168.1.139` e servidor TFTP no host `192.168.1.10`.
- O `.env` do `recovery-lab` foi ajustado para `TFTP_HOST_ADDRESS=192.168.1.10/24`.
- Teste TFTP pelo U-Boot passou:

```text
setenv ipaddr 192.168.1.139
setenv serverip 192.168.1.10
setenv gatewayip 192.168.1.1
setenv netmask 255.255.255.0
tftpboot ${loadaddr} aquario_tftp_probe.txt
```

Resultado:

```text
Speed: 100, full duplex
Using dwmac.c9410000 device
TFTP from server 192.168.1.10; our IP address is 192.168.1.139
Filename 'aquario_tftp_probe.txt'.
Load address: 0x1080000
Bytes transferred = 16 (10 hex)
```

- Em 2026-07-21 foi gravada a eMMC pelo U-Boot via TFTP + `store write`:
  - `store erase partition boot`
  - `store erase partition recovery`
  - `store erase partition vendor`
  - `store erase partition system`
  - `boot-a9.img` em `boot`
  - `recovery-a9.img` em `recovery`
  - `vendor.raw.img` em `vendor`, 8 chunks de 64 MiB
  - `system.raw.img` em `system`, 29 chunks de 64 MiB
  - `store erase partition cache`
  - `store erase partition data`
  - `saveenv`
  - `reset`
- Apos reset, U-Boot carregou o novo `boot.img` e entrou em `Starting kernel ...`.
- Nao houve log serial novo depois de `Starting kernel ...`; possivel causa: cmdline do `boot.img` novo esta curta e nao inclui `console=ttyAML0,115200` como o firmware original.
- Correcao posterior:
  - `BOARD_VENDORIMAGE_PARTITION_SIZE` ajustado de 536,870,912 para 268,435,456 bytes, pois a EPT real do aparelho tem `vendor` de 256 MiB e `odm` separado de 256 MiB.
  - `BOARD_KERNEL_CMDLINE` ajustado para incluir `rootfstype=ramfs init=/init ... console=ttyAML0,115200`.
  - Rebuild incremental `bootimage vendorimage` concluiu com sucesso.
  - Regravado `boot` com `boot-a9-console.img`.
  - Regravado `vendor` com raw de 256 MiB em 4 chunks `a9v256.000`..`a9v256.003`.
  - `odm`, `cache` e `data` foram apagadas.
  - Novo boot mostra cmdline correta:

```text
Kernel command line: rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug console=ttyAML0,115200 buildvariant=userdebug
```

- Mesmo com console na cmdline, apos `Starting kernel ...` ainda nao apareceu log serial novo; proxima suspeita: kernel/DTB/early console.

## Cartao SD / OpenWrt

- Cartao identificado no host: `/dev/sdi`, 29.7 GiB, USB `Card Reader`.
- Imagem pronta encontrada: `infra/aidan/data/openwrt_aquario_recovery_sd.img`, 1.5 GiB.
- A imagem tem MBR com particoes:
  - p1 FAT32 383 MiB
  - p2 Linux 1.3 GiB
  - p3 Linux 1023 MiB
  - p4 Linux 27.1 GiB
- Tambem existe `infra/aidan/data/openwrt_lede_amlogic_s905w_k6.12.94_2026.07.01.img.gz`.
- Tentativas iniciais de gravar `/dev/sdi` via Docker/root:
  - `dd` reportou sucesso escrevendo 1.5 GiB e sincronizando.
  - Leitura do primeiro 1 MiB apos a gravacao continuou com hash antigo `6f6f345c...`, diferente do primeiro 1 MiB da imagem `feaba100...`.
  - Teste escrevendo apenas 1 MiB via `--device=/dev/sdi:/dev/sdx` tambem reportou sucesso, mas a leitura continuou inalterada.
- Em tentativa posterior com `pkexec` e I/O direto, foi identificado que o leitor/cartao grava dados deslocados 2 bytes para frente.
- Foi aplicada compensacao escrevendo a imagem a partir do byte 3 (`tail -c +3 ... | dd of=/dev/sdi ...`), o que deixou a tabela MBR valida no cartao:

```text
/dev/sdi1  start 8192     size 383M  type W95 FAT32 (LBA)
/dev/sdi2  start 794624   size 1.3G  type Linux
/dev/sdi3  start 3418112  size 1023M type Linux
/dev/sdi4  start 5515264  size 27.1G type Linux
```

- Limitacao observada: os dois primeiros bytes fisicos do disco continuam `00 00`, enquanto a imagem original inicia com `fa b8`; o leitor nao permitiu sobrescrever esses dois bytes nem com `dd bs=1 seek=0`.
- A particao FAT `/dev/sdi1` montou em modo leitura e contem arquivos OpenWrt/boot, incluindo:
  - `aml_autoscript`
  - `aml_autoscript.cmd`
  - `s905_autoscript`
  - `s905_autoscript.cmd`
  - `uEnv.txt`
  - `zImage`
  - `uInitrd`
  - `aidan-p281-1g.dtb`
  - muitos DTBs em `dtb/amlogic/`
- Durante listagem da FAT apareceram alguns erros em `extlinux` e loop simbolico em `dtb/...`; revisar se o boot por SD falhar.
- A particao `/dev/sdi2` nao montou como filesystem Linux comum no host (`wrong fs type/bad superblock`); pode ser particao/raw esperada pela imagem, mas precisa confirmar pelo boot no aparelho.

## Restauracao da imagem original aquario.img na eMMC

- Imagem original confirmada pelo usuario: `infra/aidan/data/aquario.img`.
- Arquivos usados da extracao BSP:
  - `infra/aidan/data/aquario_bsp/dtb/aquario_0_offset_400800.dtb`
  - `infra/aidan/data/aquario_bsp/particoes/boot.img`
  - `infra/aidan/data/aquario_bsp/particoes/recovery.img`
  - `infra/aidan/data/aquario_bsp/particoes/logo.img`
  - `infra/aidan/data/aquario_bsp/particoes/rsv.img`
  - `infra/aidan/data/aquario_bsp/particoes/tee.img`
  - `infra/aidan/data/aquario_bsp/particoes/crypt.img`
  - `infra/aidan/data/aquario_bsp/particoes/misc.img`
  - `infra/aidan/data/aquario_bsp/particoes/system.img`
- Staging TFTP usado: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx`.
- Rede U-Boot/TFTP usada:
  - aparelho: `192.168.1.139`
  - servidor: `192.168.1.10`
  - gateway: `192.168.1.1`
- Sequencia principal executada no U-Boot:
  - `tftpboot 1080000 orig-dtb.img`
  - `store dtb write 1080000`
  - `store mbr 1080000`
  - `reset`
  - apagar/gravar `boot`, `recovery`, `logo`, `rsv`, `tee`, `crypt`, `misc`
  - gravar `system` em 32 chunks de 64 MiB (`origsys.000`..`origsys.031`)
  - `store erase partition cache`
  - `store erase partition data`
  - `setenv bootargs rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug console=ttyAML0,115200`
  - `saveenv`
  - `reset`
- O `store dtb write` restaurou o DTB original e recriou a tabela original com 10 particoes:
  - `logo` 32 MiB
  - `recovery` 32 MiB
  - `rsv` 8 MiB
  - `tee` 8 MiB
  - `crypt` 32 MiB
  - `misc` 32 MiB
  - `boot` 32 MiB
  - `system` 2 GiB
  - `cache` 512 MiB
  - `data` restante da eMMC
- `mmc part` apos restaurar DTB/MBR mostrou:

```text
00 bootloader start 0 sectors 8192
01 reserved   start 73728 sectors 131072
02 cache      start 221184 sectors 1048576
03 env        start 1286144 sectors 16384
04 logo       start 1318912 sectors 65536
05 recovery   start 1400832 sectors 65536
06 rsv        start 1482752 sectors 16384
07 tee        start 1515520 sectors 16384
08 crypt      start 1548288 sectors 65536
09 misc       start 1630208 sectors 65536
10 boot       start 1712128 sectors 65536
11 system     start 1794048 sectors 4194304
12 data       start 6004736 sectors 9265152
```

- Primeiro boot apos restaurar `boot/system` original:
  - U-Boot carregou Android image em `0x01080000`.
  - Kernel iniciou e passou de `Starting kernel ...`.
  - Shell serial apareceu como `STV-3000:/ $`.
  - Android reportado:

```text
ro.build.version.release = 7.1.2
ro.build.fingerprint = Amlogic/p281/p281:7.1.2/STV-3000/20220608:userdebug/test-keys
ro.product.model = STV-3000
```

- No primeiro boot, como `cache` e `data` haviam sido apagados, o log mostrou falhas iniciais:

```text
fs_mgr: Failed to mount ... /dev/block/cache at /cache
fs_mgr: /dev/block/data is wiped and /data ext4 is encryptable. Suggest recovery...
dig: /data hasn't mounted!
```

- Em boot posterior, o proprio firmware recriou/montou `cache` e `data` como ext4. Estado coletado via shell serial:

```text
/dev/block/system on /system type ext4 (ro,seclabel,relatime,data=ordered)
/dev/block/cache on /cache type ext4 (rw,seclabel,nosuid,nodev,noatime,nodelalloc,errors=panic,data=ordered)
/dev/block/data on /data type ext4 (rw,seclabel,nosuid,nodev,noatime,nodelalloc,errors=panic,data=ordered)
/dev/block/tee on /tee type ext4 (rw,seclabel,nosuid,nodev,noatime,nodelalloc,errors=panic,data=ordered)
```

```text
Filesystem        Size  Used Avail Use% Mounted on
/dev/block/system 1.9G  1.3G  626M  69% /system
/dev/block/cache  496M  508K  485M   1% /cache
/dev/block/data   4.2G   87M  4.1G   2% /data
/dev/block/tee    4.9M   35K  4.8M   1% /tee
```

- Particoes vistas pelo kernel Android:

```text
mmcblk0      7634944 KiB
mmcblk0p1       4096 KiB
mmcblk0p2      65536 KiB
mmcblk0p3     524288 KiB
mmcblk0p4       8192 KiB
mmcblk0p5      32768 KiB
mmcblk0p6      32768 KiB
mmcblk0p7       8192 KiB
mmcblk0p8       8192 KiB
mmcblk0p9      32768 KiB
mmcblk0p10     32768 KiB
mmcblk0p11     32768 KiB
mmcblk0p12   2097152 KiB
mmcblk0p13   4632576 KiB
mmcblk1     31166976 KiB
```

- Foi tentada uma restauracao adicional de `cache.img`/`data.img` brutos:
  - `orig-cache.img` preparado com 512 MiB.
  - `data.img` preparado em 71 chunks `origdata.000`..`origdata.070`.
  - A sequencia nao foi concluida porque o aparelho voltou para o Android durante a transferencia/gravação; nao houve gravacao parcial conhecida de `data`.
  - Como o segundo boot ja recriou e montou `cache`/`data`, foi mantido esse estado funcional.
- Estado final desta etapa: eMMC inicializa o Android original do `aquario.img`, com shell serial disponivel, `/system`, `/cache`, `/data` e `/tee` montados.

## Android 9 legacy no Aquario STV-3000

- Analise do Android original rodando no aparelho:
  - SoC/plataforma: Amlogic `gxl`, placa `p281`, produto Aquario/STV-3000.
  - Kernel original funcional: Linux `3.14.29`, AArch64, build `Wed May 25 14:01:50 CST 2022`.
  - Userland original: 32-bit ARM (`armeabi-v7a`, `armeabi`), sem ABI 64-bit.
  - RAM: 1 GiB.
  - GPU: Mali-450, modulo `mali`.
  - Wi-Fi: `SSV6051`, modulos `ssv6051`, `mac80211`, `cfg80211`.
  - Android original: 7.1.2, fingerprint `Amlogic/p281/p281:7.1.2/STV-3000/20220608:userdebug/test-keys`.
  - Layout original nao tem particoes `vendor` nem `odm`; `vendor` e symlink para `/system/vendor`.
- Especificacao recomendada para procurar ROM base na internet:
  - `Amlogic S905W`
  - board `p281`
  - box compativel `X96 Mini`
  - Android 9 / Pie / ATV9
  - variante `1GB RAM` e preferencialmente `8GB eMMC`
  - userspace 32-bit ARM
  - kernel/boot com suporte a Android Binder moderno (`binder`, `hwbinder`, `vndbinder`)
  - Wi-Fi `SSV6051` ou ROM em que Wi-Fi seja secundario/ajustavel
  - evitar S905X/S912/S905X2, imagens 64-bit puras, e imagens para 2GB-only quando houver variante 1GB.
- Busca web rapida em 2026-07-21 encontrou familias relevantes:
  - Aidan's ROM `[S905W] [ATV 9] (P281)`.
  - Firmwares Android 9 para X96 Mini S905W/P281.
- Ajustes feitos na AOSP9 local:
  - `BOARD_USES_VENDORIMAGE := false`.
  - `PRODUCT_FULL_TREBLE_OVERRIDE := false`.
  - `fstab.amlogic` sem `/vendor`; monta `/system`, `/cache`, `/data`, `/tee`.
  - tamanhos ajustados para o layout original: `boot` 32 MiB, `recovery` 32 MiB, `system` 2 GiB, `cache` 512 MiB, `data` restante.
  - cmdline do boot alinhada ao boot original funcional, com `console=ttyS0,115200`, `earlyprintk=aml-uart,0xc81004c0`, `androidboot.hardware=amlogic`, `androidboot.slot_suffix=_a`.
  - recompilado `bootimage systemimage` com sucesso.
- Artefatos gerados:
  - `work/tftp-aquario-android9-legacy-20260721/boot-a9-legacy.img`
  - `work/tftp-aquario-android9-legacy-20260721/system-a9-legacy.raw`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-a9-legacy.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/a9legsys.000` .. `a9legsys.031`
- Gravado na eMMC:
  - `boot-a9-legacy.img` em `boot`.
  - `system-a9-legacy.raw` em `system`, 32 chunks de 64 MiB.
  - `cache` e `data` apagados para recriacao.
- Resultado do boot Android 9 legacy:
  - U-Boot carrega boot image.
  - Kernel inicia e mostra logs.
  - `init` Android 9 inicia.
  - `/system` e lido, e o build aparece no log:

```text
Build fingerprint: 'Aquario/aquario_stv3000/stv3000:9/PI/developer07211845:userdebug/test-keys'
console:/ $
```

- Falha atual:
  - varios servicos abortam com `Binder driver could not be opened. Terminating.`
  - `hwservicemanager` tambem falha, e `servicemanager` reinicia 4 vezes.
  - Depois disso o Android 9 reinicia para `bootloader`.
  - Tambem aparecem falhas de primeiro boot em `/data`, como `/data/misc/keystore` e `/data/dalvik-cache/arm` ausentes, mas isso parece secundario enquanto Binder nao funciona.
- Tentativa feita:
  - patch em `system/core/init/init.cpp` para criar cedo:
    - `/dev/binder` major/minor `10:63`
    - `/dev/hwbinder` major/minor `10:62`
    - `/dev/vndbinder` major/minor `10:61`
  - recompilado `bootimage` e gravado como `boot-a9-binderfix.img`.
  - Resultado: erro Binder persistiu.
- Interpretacao atual:
  - o particionamento/ramdisk agora esta muito mais perto: Android 9 chega ao `init` e shell console.
  - o bloqueio principal restante e kernel Binder/HwBinder/VndBinder.
  - provavel necessidade: usar kernel Android 9 para S905W/P281 que tenha `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` ou backportar suporte equivalente para o kernel original 3.14/4.9.

## 2026-07-21 - Teste Aidan ATV9 P281 baixada do AndroidFileHost

- URL solicitada:
  - `https://ava4.androidfilehost.com/dl/cAYVuvq_8GLlGQ5Y1-pWhg/1784758262/2981970449027574722/1.+%5Bv9%5D+Aidan%27s+ROM+%5BS905W%5D+%5BATV+9%5D+%28P281%29.rar`
- Arquivo baixado:
  - `downloads/aidan_s905w_p281/aidan_s905w_atv9_p281.rar`
  - tamanho: `479187183` bytes
  - SHA256: `257351d89600724db1057fa457cc4281c548f066f76175df38a8a91d65429a63`
- Conteudo extraido:
  - `downloads/aidan_s905w_p281/extracted/1. [v9] Aidan's ROM [S905W] [ATV 9] (P281).img`
  - tamanho: `1268755628` bytes
  - SHA256: `f2a670b442e62acb3ba85725d4aac2e5a657cba8070291627da328bd88cceb9b`
  - Hash identico ao arquivo local antigo `infra/aidan/data/aidanrom.img`.
- A imagem e container Amlogic USB Burning, nao imagem raw de disco:
  - cabecalho contem `USB` e `DDR`.
  - extraido anteriormente em `infra/aidan/data/extraido`.
- Particoes/itens Aidan usados:
  - `bootloader.PARTITION` SHA256 `46e054601dd33f4ddd0c4f9b76d78b9fd3e0d415ef0d54796008a5675022d69b`
  - `_aml_dtb.PARTITION`, `boot.PARTITION`, `recovery.PARTITION`, `dtbo.PARTITION`, `logo.PARTITION`, `odm.PARTITION`, `product.PARTITION`, `system.PARTITION`, `vbmeta.PARTITION`, `vendor.PARTITION`.
  - `boot.PARTITION`: Android boot image, kernel `Linux-4.9.113`, cmdline `androidboot.dtbo_idx=0 --cmdline root=/dev/mmcblk0p18 buildvariant=userdebug`.
- Imagem raw offline completa regenerada:
  - `infra/aidan/data/aquario_aidan_full_emmc.img`
  - tamanho: `7818182656` bytes
  - SHA256: `95cf14a7e56e3190d8b01af4a4de625b63880d1d6bf6b6782c083a8860a0ac50`
  - contem bootloader Aidan nos primeiros 4 MiB.
- Flash real feito por U-Boot/TFTP, usando:
  - device IP `192.168.1.139`
  - server IP `192.168.1.10`
  - TFTP root: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx`
  - arquivos preparados em `aidan_flash_20260721_1921/`.
- Procedimento aplicado conforme pedido "nao preserva nada":
  - `store dtb write 1080000 1c800`
  - `store mbr 1080000`
  - apagadas com `store erase partition`: `cache`, `data`, `metadata`, `cri_data`, `param`, `rsv`, `tee`, `misc`, `env`.
  - gravadas particoes Aidan: `logo`, `recovery`, `dtbo`, `boot`, `vbmeta`, `odm`, `product`, `vendor` em 3 chunks, `system` em 16 chunks.
  - bootloader gravado por ultimo com `store rom_write 1080000 0 d4000`.
- Resultado antes do reset, ainda no U-Boot antigo em RAM:
  - `run storeboot` carregou o boot Aidan, mas falhou:

```text
Bad Linux ARM64 Image magic!(Maybe unsupported zip mode.)
```

- Resultado apos `reset`, usando o bootloader Aidan gravado:
  - BL2/BL31/BL33 Aidan inicia a partir da eMMC.
  - Reinicia em loop antes do prompt U-Boot.
  - Mensagem critica repetida:

```text
[Image: gxl_v1.1.3394-7d43064d5 2020-05-07 15:37:15 gongwei.chen@droid11-sz]
OPS=0xc2
Wrong chip c0
```

- Interpretacao:
  - A ROM Aidan baixada foi testada sem preservar nada, incluindo bootloader.
  - O bootloader Aidan e incompatível com esta placa/revisao/chip Aquario: falha em `Wrong chip c0` antes de chegar ao prompt.
  - A parte Android da Aidan pode ainda servir como fonte de `boot/system/vendor`, mas o bootloader completo desta ROM nao deve ser usado como base final para o Aquario.
  - Para recuperar via U-Boot agora, sera necessario usar metodo externo/boot alternativo (ex.: modo USB Burning/maskrom/SD recovery funcional), porque o bootloader gravado nao fica no prompt.

## 2026-07-21 - Cartoes SD de recuperacao

- Teste 1: cartao com bootloader cru extraido da eMMC Aquario nos primeiros 4 MiB.
  - Fonte: `infra/aidan/data/aquario_bsp/particoes/bootloader.img`
  - SHA256: `d93fc90ff4b8b13f598ff3d008751289818c1e2eba696778609ac4cbe0a7301e`
  - Resultado informado: nao iniciou pelo cartao.
- Teste 2: cartao OpenWrt/recovery pronto:
  - Imagem: `infra/aidan/data/openwrt_aquario_recovery_sd.img`
  - Gravado em `/dev/sdi`.
  - Layout: FAT `BOOT`, Btrfs `ROOTFS`, mais duas particoes.
  - Resultado informado: com eMMC fora, cartao tambem nao iniciou.
  - Interpretacao: o bootloader extraido da eMMC Aquario nao parece ser SD-bootavel diretamente.
- Teste 3 preparado: cartao Amlogic SD burn minimo.
  - Device: `/dev/sdi`
  - MBR DOS, uma particao FAT32 `BOOT` bootable iniciando no setor `32768`.
  - Arquivos na FAT:
    - `aml_sdc_burn.ini` de `infra/aidan/data/extraido/aml_sdc_burn.ini`
    - `aml_upgrade_package.img` copiado de `infra/aidan/data/aidanrom.img`
  - Blob SD burn injetado no inicio preservando bytes MBR 442-511:
    - fonte `infra/aidan/data/extraido/aml_sdc_burn.UBOOT`
    - SHA256 `c3ba17dd8a5fd73b712dc9af2e7b16601d85da9272a74f82c87110ac8af3e390`
  - Objetivo: tentar fazer o BL1 carregar o modo `sdc_burn`/recuperacao a partir do SD.
  - Risco conhecido: blob veio da Aidan e pode repetir incompatibilidade de chip, mas e o blob especifico de SD burning, diferente do `bootloader.PARTITION`.
- Resultado observado no TTL com o Teste 3:
  - BL1 carregou do SD corretamente:

```text
Load fip tmp header from SD
Load BL31 from SD
Load bl33 from SD, src: 0x00050200, des: 0x01000000, size: 0x00083200
```

  - Falhou em BL33/U-Boot Aidan:

```text
OPS=0xc2
Wrong chip c0
```

- Teste 4 preparado: blob SD burn hibrido.
  - Mantido `aml_sdc_burn.UBOOT` da Aidan como base SD-bootavel.
  - Substituido o trecho BL33 em offset `0x50200`, tamanho `0x83200`, pelo mesmo trecho do bootloader Aquario original.
  - Arquivo:
    - `work/hybrid-sd-uboot-aquario-bl33-20260721/aml_sdc_burn_hybrid_aquario_bl33.UBOOT`
    - SHA256 `8c1e68a777cfb6f612a7362390c390315e563ba8e8b9b88fd99da57ac8cea023`
  - Gravado no inicio do cartao `/dev/sdi`, preservando MBR bytes `442-511`.
  - FAT `BOOT` e arquivos `aml_sdc_burn.ini`/`aml_upgrade_package.img` mantidos.
  - Objetivo: passar do `Wrong chip c0` usando BL33/U-Boot Aquario, mas mantendo BL2/BL31 SD-bootaveis.

- Resultado do Teste 4 no TTL:
  - O cartao ainda carregou pelo caminho SD, mas continuou mostrando a imagem Aidan e falhando em `Wrong chip c0`.
  - Isso sugere que o erro pode nao estar somente no BL33 substituido, ou que o trecho BL33 dentro do `aml_sdc_burn.UBOOT` nao e trocavel isoladamente sem manter cabecalhos/assinaturas/FIP coerentes.
- Teste 5 preparado em 2026-07-21 20:22 - blob SD burn hibrido FIP:
  - Mantido o prefixo SD-bootavel da Aidan ate offset `0xc200`.
  - Substituido de `0xc200` ate o fim do arquivo pelo trecho correspondente do bootloader Aquario original, cobrindo header FIP, BL30, BL31 e BL33.
  - Arquivo:
    - `work/hybrid-sd-uboot-aquario-fip-20260721/aml_sdc_burn_hybrid_aquario_fip.UBOOT`
    - SHA256 `d6f482f019e4bc7bf5184493c6fc01c2b1161026a393ac30edda8600a282462c`
  - Gravado em `/dev/sdi`, preservando MBR bytes `442-511`.
  - Verificacao pos-gravacao OK:
    - bytes `0-441` iguais ao hibrido FIP.
    - bytes `442-511` preservados do MBR original do cartao.
    - setores `1-1696` iguais ao hibrido FIP.
  - FAT `BOOT` e arquivos `aml_sdc_burn.ini`/`aml_upgrade_package.img` mantidos.
  - Objetivo: testar se o `Wrong chip c0` vinha de BL30/BL31/header FIP da Aidan, nao apenas de BL33.
  - Resultado no TTL:
    - Melhorou: o `Wrong chip c0` sumiu.
    - BL2 ainda e o SD-bootavel da Aidan:

```text
BL2 Built : 15:21:58, Mar 26 2020. gxl g486bc38 - gongwei.chen@droid11-sz
Load fip tmp header from SD, src: 0x0000c200
Load bl30 from SD, src: 0x00010200
Load bl31 from SD, src: 0x00020200
Load bl33 from SD, src: 0x00050200, size: 0x00066400
```

    - BL30/BL31/BL33 passaram a ser os da Aquario original:

```text
NOTICE:  BL3-1: Built : 15:20:30, Feb  7 2018
[Image: gxl_v1.1.3243-377db0f 2017-09-07 11:28:58 qiufang.dai@droid07]
U-Boot 2015.01 (Sep 21 2022 - 17:26:13)
```

    - O cartao foi reconhecido no U-Boot como `SDIO Port B`, `Name: SC32G`, `Capacity: 29.7 GiB`.
    - Falha atual nao e mais incompatibilidade de chip; e o fluxo automatico `sdc_burn` tentando usar `store`/eMMC enquanto a eMMC esta ausente:

```text
emmc/sd response timeout, cmd8
MMC init failed
card in
[mmc_init] mmc init success
[MSG]ini sz 0x18aB
[MSG]=====>To burn part [_aml_dtb]
[store]To run cmd[emmc dtb_write ...]
_dtb_init()-956: mmc init failed
"Synchronous Abort" handler
```

  - Interpretacao:
    - O hibrido FIP e a primeira combinacao funcional para SD boot nesta placa.
    - Ele da U-Boot Aquario a partir do cartao, mas o arquivo `aml_sdc_burn.ini`/pacote Aidan dispara modo de gravacao eMMC.
    - Para usar o cartao como "eMMC" de teste, o proximo passo e remover/renomear `aml_sdc_burn.ini` e preparar um boot manual pelo SD (`boot.scr`, `extlinux.conf` ou comandos U-Boot via TTL), evitando o subsistema `store`.

## 2026-07-21 20:32 - Cartao OpenWrt com bootloader SD hibrido funcional

- Cartao detectado no host como `/dev/sdi`, `STORAGE DEVICE`, 29.7 GiB.
- Gravada a imagem base:
  - `infra/aidan/data/openwrt_aquario_recovery_sd.img`
  - layout resultante:
    - `/dev/sdi1` FAT `BOOT`, 383 MiB
    - `/dev/sdi2` btrfs `ROOTFS`, 1.3 GiB, UUID `502240b4-2d6a-4832-97d3-841633fc0ae8`
    - `/dev/sdi3` 1023 MiB
    - `/dev/sdi4` 27.1 GiB
- Injetado por cima o bootloader SD hibrido FIP funcional:
  - `work/hybrid-sd-uboot-aquario-fip-20260721/aml_sdc_burn_hybrid_aquario_fip.UBOOT`
  - bytes `0-441` gravados no inicio do disco.
  - setores `1-1696` gravados no inicio do disco.
  - MBR/tabela da imagem OpenWrt preservada nos bytes `442-511`.
  - verificacao pos-gravacao OK com `cmp`.
- O `aml_sdc_burn.ini` nao existe mais neste layout; isso evita entrar no modo burn automatico que chamava `store`/eMMC.
- Particao BOOT montada em `/mnt/sdi1_boot` para ajustes:
  - backups criados:
    - `s905_autoscript.cmd.backup_20260721_2038`
    - `s905_autoscript.backup_20260721_2038`
    - `boot.cmd.backup_20260721_2038`
    - `boot.scr.backup_20260721_2038`
  - `s905_autoscript.cmd` substituido por script de boot OpenWrt direto em `mmc 0:1`.
  - `s905_autoscript` recompilado com `mkimage -C none -A arm -T script`.
  - `boot.cmd` ajustado para tentar `mmc 0 1`, nao somente `mmc 1`.
  - `boot.scr` recompilado.
- Configuracao de boot atual:
  - kernel: `/zImage`
  - initrd: `/uInitrd`
  - dtb: `/dtb/amlogic/meson-gxl-s905w-p281.dtb`
  - rootfs: `root=UUID=502240b4-2d6a-4832-97d3-841633fc0ae8 rootfstype=btrfs rootflags=compress=zstd:6 rw rootwait`
  - console: `ttyAML0,115200n8`
- Cartao desmontado e pronto para teste no aparelho.

## 2026-07-21 20:34 - Acesso ao U-Boot via TTL

- Prompt capturado com Ctrl-C pelo broker TTL:

```text
A95X#
```

- Versao confirmada:

```text
U-Boot 2015.01 (Sep 21 2022 - 17:26:13)
aarch64-none-elf-gcc ... 4.8.3
```

- Dispositivos MMC:

```text
SDIO Port B: 0
SDIO Port C: 1
```

- `mmc dev 0` e `mmc info` funcionaram; cartao detectado como:

```text
Device: SDIO Port B
Name: SC32G
Capacity: 29.7 GiB
Bus Width: 4-bit
```

- `fatls mmc 0:1` listou a particao BOOT com:
  - `aml_autoscript`
  - `s905_autoscript`
  - `boot.scr`
  - `uenv.txt`
  - `zimage`
  - `uinitrd`
  - `dtb/`
  - backups dos scripts anteriores.
- Ambiente importante observado:
  - `bootcmd=run storeboot`
  - `preboot=... run switch_bootmode`
  - `recovery_from_sdcard` carrega `aml_autoscript` por `fatload mmc 0 ${loadaddr} aml_autoscript; autoscr ${loadaddr}`.
  - `ipaddr=10.18.9.97`, `serverip=10.18.9.113` no ambiente default atual; ainda nao foram ajustados para `192.168.1.139`/`192.168.1.10` nesta sessao.
- Estado: U-Boot acessivel e comandos pelo TTL funcionando.

## 2026-07-21 20:41 - Cartao como ROM Aidan/Android 9

- Pedido: nao insistir no OpenWrt; fazer funcionar pelo cartao a ROM Aidan/Android 9.
- Cartao no host: `/dev/sdi`, 29.7 GiB.
- Gravada imagem completa:
  - fonte: `infra/aidan/data/aquario_aidan_full_emmc.img`
  - tamanho: `7818182656` bytes, 7.3 GiB
  - conteudo: ROM Aidan/Android 9 reconstruida como imagem eMMC completa.
- Depois da imagem completa, reinjetado o bootloader SD hibrido funcional:
  - fonte: `work/hybrid-sd-uboot-aquario-fip-20260721/aml_sdc_burn_hybrid_aquario_fip.UBOOT`
  - bytes `0-441` gravados no inicio do disco.
  - setores `1-1696` gravados no inicio do disco.
  - verificacao com `cmp` OK.
- `fdisk` nao mostra particoes DOS, esperado para layout Amlogic/EPT da ROM.
- Heuristica de validacao:
  - inicio do disco mostra blob Amlogic SD.
  - setor `0x200` contem marcador `@AML`.
- Estado: cartao pronto para teste no aparelho como "eMMC" Aidan/Android 9 com bootloader Aquario hibrido.
- Proximo teste pelo TTL:
  - interromper no `A95X#`
  - tentar `run storeboot`
  - se falhar, testar leitura direta com comandos `imgread kernel boot ${loadaddr}` e comandos MMC/store para descobrir se o U-Boot enxerga as particoes Amlogic no SD como boot device.

## 2026-07-21 - Analise do boot Aidan pelo cartao

- Resultado com ROM Aidan no cartao:
  - U-Boot hibrido entra no prompt `A95X#`.
  - `run storeboot` falha porque o subsistema `store/imgread` tenta usar o dispositivo eMMC/`store`, nao o SD como boot device:

```text
Cannot find dev.
amlmmc cmd <NULL> failed
[burnup]Err:store_read_ops,L63:cmd failed, ret=1, [store read boot ...]
```

  - O U-Boot enxerga o cartao como bloco AML:

```text
mmc dev 0
init_part() 293: PART_TYPE_AML
[mmc_init] mmc init success
```

  - `mmc part` nao lista particoes normais:

```text
Partition Map for MMC device 0 -- Partition Type: AML
** Partition 0 not found on device 0 **
** No boot partition found on device 0 **
```

- EPT Aidan relevante:
  - `boot` offset `0x55c00000`, tamanho `0x1000000`.
  - em blocos de 512: offset `0x2ae000`, tamanho `0x8000`.
  - `reserved` contem MPT/EPT em `0x2400000`.
  - multi-DTB detectado na imagem em `0x2800000` e `0x2840000`.
- Leitura direta da particao `boot` Aidan funcionou:

```text
mmc read ${loadaddr} 0x2ae000 0x8000
32768 blocks read: OK
```

- Falha do boot original Aidan:
  - boot image Aidan contem kernel `Linux-4.9.113` como uImage `ARM` 32-bit.
  - U-Boot Aquario e AArch64; rejeita:

```text
Bad Linux ARM64 Image magic!(Maybe unsupported zip mode.)
Unsupported Architecture 0x2
```

- Teste com boot Android 9 local:
  - TFTP configurado:
    - `ipaddr=192.168.1.139`
    - `serverip=192.168.1.10`
  - `ping 192.168.1.10` OK.
  - `tftpboot 0x1080000 boot-a9-legacy.img` OK:

```text
Bytes transferred = 8763392 (85b800 hex)
```

  - Gravado no cartao, particao `boot`, offset bruto Aidan:

```text
mmc write 0x1080000 0x2ae000 0x42dc
17116 blocks written: OK
```

  - Relido OK:

```text
mmc read 0x1080000 0x2ae000 0x42dc
17116 blocks read: OK
```

  - `bootm 0x1080000` passou a aceitar Android boot image, mas falhou por DTB ausente/invalido na RAM:

```text
## Booting Android Image at 0x01080000 ...
load dtb from 0x1000000 ......
Amlogic multi-dtb tool
Cannot find legal dtb!
load dtb from 0x3472ab50 ......
Cannot find legal dtb!
## No Flattened Device Tree
Could not find a valid device tree
FDT and ATAGS support not compiled in - hanging
### ERROR ### Please RESET the board ###
```

- Interpretacao:
  - O boot pelo cartao esta mecanicamente funcionando.
  - O boot original Aidan nao serve com o U-Boot Aquario porque o kernel e 32-bit ARM.
  - Substituir `boot` por `boot-a9-legacy.img` resolve a incompatibilidade de arquitetura, mas precisa carregar DTB antes do `bootm`.
  - Proximo teste apos reset fisico: no `A95X#`, executar:

```text
mmc dev 0
mmc read 0x1000000 0x14000 0x200
bootm 0x1080000
```

  - Se ainda falhar, testar o segundo DTB:

```text
mmc read 0x1000000 0x14200 0x200
bootm 0x1080000
```

## 2026-07-21 - ROM Aidan A95X F3 Air S905X3 ATV9

- Arquivo solicitado pelo usuario:
  - `downloads/[v9]+Aidan's+ROM+(A95X+F3+Air)+[S905X3]+[ATV+9].rar`
  - SHA256 do RAR: `e6e252e840f1dec0afbbceb57c81b85a23fb196d1d61584b651feac8e633a90a`
- Conteudo do RAR:
  - `[v9] Aidan's ROM (A95X F3 Air) [S905X3] [ATV 9].img`
  - extraido em `downloads/aidan_a95x_f3_air_s905x3/extracted/[v9] Aidan's ROM (A95X F3 Air) [S905X3] [ATV 9].img`
  - SHA256 da `.img`: `0c01f25e68ba3558dcb28b17c00e4101e44460713d6b63f85edb22d6b792c99f`
- Ferramenta usada para unpack:
  - `infra/aidan/data/ampack/target/release/ampack`
  - logs:
    - `downloads/aidan_a95x_f3_air_s905x3/ampack_verify.txt`
    - `downloads/aidan_a95x_f3_air_s905x3/ampack_unpack.txt`
  - saida:
    - `downloads/aidan_a95x_f3_air_s905x3/unpacked`
- Particoes/arquivos extraidos principais:
  - `boot.PARTITION`: Android bootimg, kernel size `0x919920`, sem ramdisk, second stage `0x1361f`, page size `2048`.
  - `recovery.PARTITION`: Android bootimg, mesmo kernel, ramdisk `0x65fb6a`, second stage `0x1361f`.
  - `system.PARTITION`: ext filesystem, volume `system`, 1000 MiB.
  - `vendor.PARTITION`: ext filesystem, volume `vendor`, 180 MiB.
  - `_aml_dtb.PARTITION`, `meson1.dtb`, `bootloader.PARTITION`, `aml_sdc_burn.UBOOT`.
- Extracao manual do boot:
  - `downloads/aidan_a95x_f3_air_s905x3/boot_extract/boot.PARTITION.kernel`
  - `downloads/aidan_a95x_f3_air_s905x3/boot_extract/boot.PARTITION.second_dtb`
  - `downloads/aidan_a95x_f3_air_s905x3/boot_extract/recovery.PARTITION.kernel`
  - `downloads/aidan_a95x_f3_air_s905x3/boot_extract/recovery.PARTITION.ramdisk`
  - `downloads/aidan_a95x_f3_air_s905x3/boot_extract/recovery.PARTITION.second_dtb`
- Kernel/DTB dessa ROM:
  - kernel extraido comeca com assinatura `@AML`.
  - nao apareceu `ARMd`, `uImage`, gzip, LZ4 frame, FDT/DTB claro, ELF ou string `Linux version`.
  - segundo estagio/DTB tambem nao apareceu como FDT claro.
  - `meson1.dtb` e gzip, mas ao descomprimir vira blob `AML_...`, nao FDT (`dtc` falha com `Blob has incorrect magic number`).
  - conclusao: boot/kernel/DTB estao em formato Amlogic protegido/encapsulado e nao parecem diretamente utilizaveis pelo U-Boot antigo/hibrido do Aquario.
- Propriedades Android coletadas:
  - `ro.build.version.release=9`
  - `ro.build.version.sdk=28`
  - `ro.build.display.id=Aidan's ROM v9 [AMPI.3933.M4GC release-keys]`
  - `ro.build.date=Tue Sep 28 18:09:55 CST 2021`
  - `ro.build.fingerprint=Xiaomi/oneday/oneday:9/PI/3933:user/release-keys`
  - `ro.build.system_root_image=true`
  - `ro.treble.enabled=true`
  - `ro.product.cpu.abilist=armeabi-v7a,armeabi`
  - `ro.product.cpu.abilist64=` vazio
  - `ro.vendor.product.cpu.abilist=armeabi-v7a,armeabi`
  - `ro.vendor.product.cpu.abilist64=` vazio
  - `ro.product.board=A95X_F3`
  - `ro.board.platform=franklin`
  - `ro.product.vendor.model=A95X_F3_Air`
  - `ro.product.vendor.device=ampere`
  - `ro.platform.g12=true`
- Interpretacao:
  - A ROM F3 Air/S905X3 e Android 9, mas userland 32-bit, nao uma base 64-bit.
  - Ela e de familia G12/Franklin/S905X3, nao GXL/P281/S905W.
  - Nao e boa candidata para bootloader/DTB/kernel no Aquario STV3000.
  - Pode servir como referencia de userspace Android 9 Amlogic 32-bit, mas o nosso bloqueio principal continua sendo kernel Android 9 compativel com S905W/GXL, AArch64 no boot e com binder/hwbinder/vndbinder.

## 2026-07-21 - Teste isolado do bootloader F3 Air no cartao

- Dispositivo do cartao no host no momento do teste:
  - `/dev/sdi`
  - 29.7 GiB, `Generic STORAGE DEVICE`, removivel, sem particoes montadas.
- Backup feito antes de alterar o cartao:
  - diretorio: `work/backups-sd-bootloader-20260721-f3air-test`
  - primeiros 16 MiB do cartao: `sdi_first_16m_before_f3air_uboot.bin`
  - SHA256: `ec0e8b61fcfcd9d9f3de0215170f3a7905cb1728dab48ec05e0e81e752e718e2`
  - copia do bootloader SD hibrido funcional: `aml_sdc_burn_hybrid_aquario_fip_functional.UBOOT`
  - SHA256 funcional: `d6f482f019e4bc7bf5184493c6fc01c2b1161026a393ac30edda8600a282462c`
- Bootloader F3 Air usado para teste:
  - fonte: `downloads/aidan_a95x_f3_air_s905x3/unpacked/aml_sdc_burn.UBOOT`
  - copia: `work/backups-sd-bootloader-20260721-f3air-test/aml_sdc_burn_f3air_s905x3_test.UBOOT`
  - tamanho: `1339248` bytes
  - SHA256: `4b8ec8af9304ed7f6372c0c84d4e13813cf39a005b4d80bdbf9dc443ee9c7d9e`
- Gravacao feita somente no inicio do cartao:

```text
dd if=downloads/aidan_a95x_f3_air_s905x3/unpacked/aml_sdc_burn.UBOOT of=/dev/sdi bs=512 conv=notrunc,fsync
```

- Leitura de volta:
  - `work/backups-sd-bootloader-20260721-f3air-test/sdi_readback_f3air_aml_sdc_burn.UBOOT`
  - SHA256 igual ao arquivo fonte: `4b8ec8af9304ed7f6372c0c84d4e13813cf39a005b4d80bdbf9dc443ee9c7d9e`
  - `cmp` retornou OK.
- Restauracao rapida do bootloader funcional, se o teste F3 Air falhar:

```text
sudo dd if=work/backups-sd-bootloader-20260721-f3air-test/aml_sdc_burn_hybrid_aquario_fip_functional.UBOOT of=/dev/sdi bs=512 conv=notrunc,fsync
sync
```

- Resultado no aparelho:
  - com o `aml_sdc_burn.UBOOT` da F3 Air/S905X3, o Aquario nao leu/nao iniciou pelo cartao.
  - interpretacao: BL2/SD boot dessa familia G12/S905X3 nao e aceito pelo caminho de boot do S905W/GXL do Aquario.
- Restaurado no cartao o bootloader SD hibrido funcional:

```text
dd if=work/backups-sd-bootloader-20260721-f3air-test/aml_sdc_burn_hybrid_aquario_fip_functional.UBOOT of=/dev/sdi bs=512 conv=notrunc,fsync
```

  - readback salvo em `work/backups-sd-bootloader-20260721-f3air-test/sdi_readback_restored_hybrid.UBOOT`
  - SHA256 readback: `d6f482f019e4bc7bf5184493c6fc01c2b1161026a393ac30edda8600a282462c`
  - `cmp` OK.

## 2026-07-21 - Cartao com kernel Khadas 4.9 ARM64/p281

- Objetivo:
  - retestar a trilha de compilar/usar kernel Android Pie 4.9 para S905W/GXL.
  - usar kernel ARM64 com binder em vez do kernel 3.14 original sem binder funcional para Android 9.
- Kernel ja compilado:
  - fonte: `work/khadas-linux-pie`
  - branch: `khadas-vims-pie`
  - commit: `d7123654`
  - artefato: `work/teste-khadas-stv3000/Image.gz`
  - `vmlinux`: ELF 64-bit LSB ARM aarch64
  - versao: `Linux version 4.9.113-gd7123654-dirty`
  - SHA256 `Image.gz`: `9aaf77330dc2b8767e8295f566d1847ecc5f34795b426d5618455bd100901ea2`
- Config relevante confirmada em `work/teste-khadas-stv3000/kernel.config`:
  - `CONFIG_ANDROID_BINDER_IPC=y`
  - `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
  - `CONFIG_ASHMEM=y`
  - `CONFIG_ION=y`
  - `CONFIG_SECURITY_SELINUX=y`
  - `CONFIG_COMPAT=y`
- DTB escolhido para este reteste:
  - `work/teste-khadas-stv3000/dtbs/gxl_p281_1g.dtb`
  - SHA256: `d3f771ffb421834b2d65ecc15f2006ed6b40a9b5c51f2138f762f408cd6f086c`
- Boot image gravada no cartao:
  - `work/teste-khadas-stv3000/novas-imagens-boot/boot-khadas-aosp9-gxl_p281_1g.img`
  - Android bootimg, kernel addr `0x1080000`, ramdisk addr `0x1000000`, page size `2048`.
  - cmdline: `androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug console=ttyAML0,115200`
  - tamanho: `10266624` bytes
  - SHA256: `c44d9df765f9c7cb8ff83a740da9997e1f1cb2a462c75f006692aff060ef6692`
- Cartao no host durante a gravacao:
  - `/dev/sdi`, 29.7 GiB, `Generic STORAGE DEVICE`, removivel.
  - bootloader SD hibrido funcional ja restaurado no inicio do cartao.
- Backup antes de sobrescrever o `boot`:
  - `work/sd-khadas-p281-test-20260721/sdi_boot_before_khadas_p281.img`
  - tamanho: 16 MiB
  - SHA256: `b03e5c79123847aaa0adca7bebeab83867ff26349555d4eccaeb248dfa43a5b3`
- Offset bruto da particao `boot` no layout Aidan do cartao:
  - setores de 512 bytes: offset `0x2ae000`, tamanho `0x8000`
  - bytes: offset `0x55c00000`, tamanho `0x1000000`
- Gravacao realizada:

```text
dd if=work/teste-khadas-stv3000/novas-imagens-boot/boot-khadas-aosp9-gxl_p281_1g.img of=/dev/sdi bs=512 seek=$((0x2ae000)) conv=notrunc,fsync
dd if=/dev/zero of=/dev/sdi bs=512 seek=$((0x2ae000 + 20052)) count=12716 conv=notrunc,fsync
```

  - setores gravados do boot.img: `20052`
  - restante da particao boot zerado: `12716` setores
- Readback:
  - `work/sd-khadas-p281-test-20260721/sdi_boot_readback_khadas_p281.img`
  - SHA256 igual ao fonte: `c44d9df765f9c7cb8ff83a740da9997e1f1cb2a462c75f006692aff060ef6692`
  - `cmp` OK.
- Copia para TFTP:
  - `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-aosp9-gxl_p281_1g.img`
  - SHA256: `c44d9df765f9c7cb8ff83a740da9997e1f1cb2a462c75f006692aff060ef6692`
- Se o boot automatico pelo cartao nao usar a particao `boot`, testar manualmente no `A95X#`:

```text
mmc dev 0
mmc read 0x1080000 0x2ae000 0x4e54
bootm 0x1080000
```

  - `0x4e54` e o tamanho arredondado em setores do `boot-khadas-aosp9-gxl_p281_1g.img`.

## 2026-07-21 - Clone limpo Khadas e compilacao pelo container

- Pedido do usuario:
  - arquivar a arvore/kernel atual;
  - baixar novamente do GitHub;
  - compilar pelo container correto;
  - testar do zero.
- Arquivo da arvore/build anterior:
  - diretorio: `work/archives/kernel-khadas-20260721-before-fresh`
  - tar: `khadas-linux-pie-current-plus-build-20260721.tar.zst`
  - conteudo arquivado:
    - `work/khadas-linux-pie`
    - `work/build-khadas-stv3000`
    - `work/teste-khadas-stv3000`
    - scripts principais de compilacao
  - SHA256: `5b2730ca1300a0c99346009eb25bc6a89acf0440e6b05822f0a2526fe2fb51dc`
  - diff local separado:
    - `work/archives/kernel-khadas-20260721-before-fresh/gxl_p281_1g.local.diff`
  - a arvore antiga tinha modificacao local em `arch/arm64/boot/dts/amlogic/gxl_p281_1g.dts`.
- Clone limpo:
  - fonte: `https://github.com/khadas/linux.git`
  - branch: `khadas-vims-pie`
  - destino: `work/khadas-linux-pie-fresh-20260721`
  - commit: `d71236547be9b86d527de0f62c2092ec032fd0fa`
- Container usado:
  - `android9-aquario`
  - imagem: `android9-aquario-builder:latest`
  - caminho interno: `/workspace/firmware-lab`
  - toolchain: `/workspace/firmware-lab/infra/aidan/aosp9/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-`
  - GCC: `real-aarch64-linux-android-gcc (GCC) 4.9.x 20150123 (prerelease)`
  - paralelo usado: `-j16`
- Build limpo:
  - source: `/workspace/firmware-lab/work/khadas-linux-pie-fresh-20260721`
  - out: `/workspace/firmware-lab/work/build-khadas-fresh-20260721/kernel-out`
  - resultado: `work/teste-khadas-fresh-20260721`
  - log inicial: `work/teste-khadas-fresh-20260721/build-kernel-container.log`
  - log retry: `work/teste-khadas-fresh-20260721/build-kernel-container-retry-usbnet.log`
- Config aplicada:
  - defconfig: `meson64_defconfig`
  - `CONFIG_ANDROID_BINDER_IPC=y`
  - `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
  - `CONFIG_ASHMEM=y`
  - `CONFIG_ION=y`
  - `CONFIG_COMPAT=y`
  - `CONFIG_DEVTMPFS=y`
  - `CONFIG_BLK_DEV_INITRD=y`
  - `CONFIG_SECURITY_SELINUX=y`
- Falha encontrada no primeiro link:
  - `GobiUSBNet.c` referenciava simbolos `usbnet_*` ausentes:
    - `usbnet_suspend`
    - `usbnet_resume`
    - `usbnet_disconnect`
    - `usbnet_start_xmit`
    - `usbnet_probe`
    - `usbnet_tx_timeout`
    - `usbnet_skb_return`
  - causa: `CONFIG_USB_USBNET` estava desativado enquanto `GobiUSBNet` entrou no build.
  - correcao minima aplicada no build limpo: `CONFIG_USB_USBNET=y`.
  - apos isso o build completou.
- Artefatos gerados pelo build limpo:
  - `work/teste-khadas-fresh-20260721/Image.gz`
    - SHA256: `4f061b14a4c9f1418a53367e8bfb08132bbe6eaacfdd5e16144e81ed9a8351b6`
  - `work/teste-khadas-fresh-20260721/Image`
    - SHA256: `99b98b460230746e4f5b0d9f2b79a768bfc99b9b3957b556be65f3cfd3e4fbed`
  - `work/teste-khadas-fresh-20260721/vmlinux`
    - ELF 64-bit ARM aarch64
    - SHA256: `3483f060dcc013ba593d13d4329cd14ffe98c0687a1df1d3af5e132adf6e7fb6`
  - `work/teste-khadas-fresh-20260721/dtbs/gxl_p281_1g.dtb`
    - SHA256: `363ed60989d76e66e96ed082dc83bde60dfe84a91ab7d933d811cc6582714dc4`
  - `work/teste-khadas-fresh-20260721/dtbs/gxl_p281_2g.dtb`
    - SHA256: `52960bdd38774f4d113a310d2434dd8254b7eec94ab78c37f0851fa939b962f6`
- Boot image fresca gerada:
  - `work/teste-khadas-fresh-20260721/bootimgs/boot-khadas-fresh-p281-debugcmd.img`
  - SHA256: `b9fbe93d34a4648c22eec0c436b63c3cdc130ff1e8ea60ed814ff4625c6f72d6`
  - tamanho: `10174464` bytes
  - kernel: `work/teste-khadas-fresh-20260721/Image.gz`
  - ramdisk: `infra/aidan/aosp9/out/target/product/stv3000/ramdisk.img`
  - cmdline:

```text
rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug console=ttyAML0,115200 no_console_suspend earlyprintk=aml-uart,0xc81004c0 ignore_loglevel loglevel=8 initcall_debug maxcpus=4
```

  - copia TFTP:
    - `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-debugcmd.img`
- Estado do teste:
  - o teste anterior com kernel Khadas antigo + multi-DTB chegou a:

```text
Starting kernel ...
```

  - depois ficou sem logs.
  - tentativa de leitura serial depois disso nao retornou nada; provavelmente o SoC ficou preso no kernel.
  - para testar a imagem fresca via TFTP, precisa reset fisico/energia para voltar ao `A95X#`.


## 2026-07-21 - Teste TFTP do kernel Khadas fresco

- Imagem testada via TFTP:
  - `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-debugcmd.img`
  - SHA256: `b9fbe93d34a4648c22eec0c436b63c3cdc130ff1e8ea60ed814ff4625c6f72d6`
- Comandos usados no `A95X#`:

```text
setenv ipaddr 192.168.1.139
setenv serverip 192.168.1.10
tftpboot 0x1080000 boot-khadas-fresh-p281-debugcmd.img
mmc dev 0
mmc read 0x1000000 0x14000 0x200
md.b 0x1000000 0x40
bootm 0x1080000
```

- TFTP funcionou:
  - `Bytes transferred = 10174464 (9b4000 hex)`
- Multi-DTB externo do cartao foi carregado em `0x1000000`:
  - assinatura `AML_`
  - U-Boot detectou `Multi dtb tool version: v2`
  - suportava 2 DTBs: `gxl/p281/1g` e `gxl/p281/2g`
  - escolheu `Find match dtb: 0`
- Boot chegou a:

```text
Uncompressing Kernel Image ... OK
kernel loaded at 0x01080000, end = 0x0263b008
Loading Ramdisk to 33d15000, end 33ea06c5 ... OK
Loading Device Tree to 000000001fff2000, end 000000001ffff833 ... OK
Starting kernel ...
```

- Resultado apos `Starting kernel ...`:
  - nao houve log do kernel apesar de `console=ttyAML0,115200`, `earlyprintk=aml-uart,0xc81004c0`, `ignore_loglevel` e `loglevel=8`.
  - alguns segundos depois o aparelho reiniciou e voltou ao BL1/BL2/U-Boot pelo cartao.
  - isso indica crash/watchdog muito cedo no kernel, antes de console normal ou early console produzir saida.
- Estado apos o teste:
  - voltou ao prompt `A95X#`.
  - apareceram alguns caracteres espurios `�` na serial, provavelmente sobra/ruido do cliente nc/comandos, nao comando valido.
- Proxima hipotese:
  - o problema deve estar em incompatibilidade de DTB/reserved-memory/psci/optee/clock/reset para esse BL31/placa, ou em console earlyprintk incorreto para esse kernel.
  - testar uma imagem com `earlycon=aml-uart,0xc81004c0` e/ou `earlycon=uart,mmio32,0xc81004c0` pode ajudar.
  - tambem testar `gxl_p281_2g` apesar de a placa ter 1 GiB pode confirmar se o DTB escolhido derruba cedo, mas risco de mapa de memoria errado.


## 2026-07-21 - Kernel Khadas fresco com earlycon: melhora grande e panic real

- Foi gerada/testada a imagem:
  - `work/teste-khadas-fresh-20260721/bootimgs/boot-khadas-fresh-p281-earlycon.img`
  - copia TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-earlycon.img`
  - cmdline principal:

```text
rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug console=ttyAML0,115200 earlycon=aml-uart,0xc81004c0 keep_bootcon ignore_loglevel loglevel=8 no_console_suspend maxcpus=4
```

- Com `setenv bootargs` antes do `bootm`, o U-Boot nao misturou os bootargs antigos e o kernel passou a imprimir logs limpos.
- O usuario resumiu bem: "melhorou 80%". Agora o problema deixou de ser silencio total e virou crash especifico no kernel.
- Comandos usados no U-Boot:

```text
setenv ipaddr 192.168.1.139
setenv serverip 192.168.1.10
tftpboot 0x1080000 boot-khadas-fresh-p281-earlycon.img
mmc dev 0
mmc read 0x1000000 0x14000 0x200
setenv bootargs
bootm 0x1080000
```

- Resultado importante:
  - Linux 4.9.113 AArch64 iniciou.
  - 4 CPUs detectados.
  - suporte 32-bit EL0 presente.
  - `ashmem: initialized` apareceu.
  - binder foi compilado na config (`CONFIG_ANDROID_BINDER_IPC=y` e dispositivos binder/hwbinder/vndbinder).
  - multi-DTB externo do cartao funcionou e selecionou `gxl/p281/1g`.
- Avisos ainda nao fatais:
  - `secmon: can't fine clear_range`
  - `secmon reserve memory init fail:-22`
  - warning em `meson_secmon_init+0x3c/0x50`
  - `vpu_probe: no match table`
  - `invalid VPU in current chip`
  - `cpu0 supply cpu not found`
  - `failed to get cpu clock -22`
  - clocks da UART ausentes, mas o console registrou e continuou.
- Panic fatal:

```text
Unable to handle kernel NULL pointer dereference at virtual address 00000004
PC is at aml_aes_probe+0x88/0x6d8
Call trace: aml_aes_driver_init -> do_one_initcall -> kernel_init_freeable
Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b
```

- Analise do codigo:
  - o crash cai em `drivers/amlogic/crypto/aml-aes-dma.c`.
  - `aml_aes_probe()` faz `aes_dd->dma = dev_get_drvdata(dev->parent);` e acessa `aes_dd->dma->thread` sem checar NULL.
  - isso sugere incompatibilidade de DTB/ordem de probe/pai do dispositivo crypto para esse conjunto BL31 + DTB + placa.
- Decisao de proximo teste:
  - recompilar o kernel com crypto de hardware Amlogic desativado:
    - `CONFIG_AMLOGIC_CRYPTO=n`
    - `CONFIG_AMLOGIC_CRYPTO_DMA=n`
    - `CONFIG_AMLOGIC_CRYPTO_BLKMV=n`
  - manter crypto generico ARM64/AES:
    - `CONFIG_CRYPTO_AES=y`
    - `CONFIG_CRYPTO_AES_ARM64_CE=y`
    - `CONFIG_CRYPTO_AES_ARM64_CE_BLK=y`
  - gerar `boot-khadas-fresh-p281-earlycon-nocrypto.img` e testar via TFTP com `bootargs` limpo.

## 2026-07-21 - Teste nocrypto e nota sobre SSH

- Pergunta do usuario: se da para deixar SSH server pre-habilitado no aparelho.
- Resposta tecnica:
  - sim, no OpenWrt e direto: `dropbear` pode ficar habilitado por padrao.
  - no Android 9 tambem e possivel, mas o caminho mais nativo para debug inicial e `adbd` por USB/TCP (`service.adb.tcp.port=5555`, `ro.adb.secure=0` em build userdebug/eng) ou incluir `dropbear/openssh` no ramdisk/system com chaves/init rc.
  - decisao para agora: primeiro estabilizar o kernel ate shell/init; depois pre-habilitar acesso remoto na imagem final.
- Imagem testada via TFTP:
  - `boot-khadas-fresh-p281-earlycon-nocrypto.img`
  - SHA256: `79373646fc137353962aca06f20a4c409695cd57c74cc4e60de06f5fd17576ba`
  - TFTP transferiu `10158080 (9b0000 hex)`.
- Resultado:
  - a correcao de config funcionou: o panic em `aml_aes_probe` sumiu.
  - o kernel passou muito alem do ponto anterior.
  - novo fatal apareceu em video/VPP:

```text
Unable to handle kernel paging request at virtual address 0000b800
PC is at vpp_get_hist_en+0x44/0x224
Call trace: vpp_get_hist_en -> aml_vecm_probe -> aml_vecm_init -> do_one_initcall
Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b
```

- Antes do fatal tambem apareceu:

```text
vpu: error: vpu_probe: no match table
vpu: error: invalid VPU in current chip
sysfs: cannot create duplicate filename '/class/amvdec_656in'
amvdec_656in: probe of d0050000.amvdec_656in1 failed with error -17
```

- Interpretacao:
  - agora e codigo/config/DTB de video, nao mais binder nem AES.
  - o driver VECM/VPP tenta acessar registrador baseado em `vpp_base`/mapa VCBUS invalido para este chip/DTB.
  - proximo teste deve desativar VECM/VPP/decoder analogico desnecessario para boot headless, ou ajustar DTB para nao instanciar esses nos.

## 2026-07-21 - VECM confirmado como bloco problemático

- Teste `boot-khadas-fresh-p281-earlycon-vecmpatch.img`:
  - SHA256: `dc16fde5d1953c9dcfd01ad0cc66bd12348b32f167e050df6a5d12a83f6a12ce`
  - TFTP transferiu `10153984 (9af000 hex)`.
- Patch aplicado inicialmente:
  - arquivo: `work/khadas-linux-pie-fresh-20260721/drivers/amlogic/media/enhancement/amvecm/amvecm.c`
  - `aml_vecm_probe()` deixou de chamar `vpp_get_hist_en()`.
- Resultado:
  - o panic em `vpp_get_hist_en` sumiu.
  - o probe continuou e caiu em outro ponto do mesmo bloco VECM:

```text
VECM: skip initial VPP histogram enable on Aquario bring-up
Unable to handle kernel paging request at virtual address 00009c68
PC is at vlock_status_init+0xa4/0x230
Call trace: vlock_status_init -> aml_vecm_probe -> aml_vecm_init
Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b
```

- Conclusao:
  - VECM/VPP inteiro esta incompatível com esse DTB/base de registradores no S905W Aquario.
  - `CONFIG_AMLOGIC_MEDIA_ENHANCEMENT_VECM=n` quebrou compilacao porque outros drivers ainda assumem structs/simbolos de HDR/VECM.
  - proximo patch: manter VECM compilado, mas fazer `aml_vecm_probe()` retornar `-ENODEV` logo no inicio para boot headless.

## 2026-07-21 - Tentativa de salvar variaveis TFTP no U-Boot

- Pedido do usuario: no proximo TFTP deixar variaveis de ambiente salvas para agilizar.
- Comandos enviados:

```text
setenv ipaddr 192.168.1.139
setenv serverip 192.168.1.10
setenv bootcmd_tftp_android9 'tftpboot 0x1080000 boot-khadas-fresh-p281-earlycon-vecmdisabled.img; mmc dev 0; mmc read 0x1000000 0x14000 0x200; setenv bootargs; bootm 0x1080000'
saveenv
printenv ipaddr serverip bootcmd_tftp_android9
```

- Resultado:
  - `ipaddr`, `serverip` e `bootcmd_tftp_android9` ficaram definidos na sessao atual.
  - `saveenv` falhou:

```text
Saving Environment to aml-storage...
emmc/sd response timeout, cmd8
MMC init failed
```

- Consequencia:
  - enquanto o U-Boot nao resetar, da para usar `run bootcmd_tftp_android9`.
  - apos reset, o U-Boot volta a `Using default environment`; precisa reenviar as variaveis ou corrigir backend/env no bootloader.

## 2026-07-21 - Ophub/OpenWrt e proximo panic Bluetooth

- Usuario sugeriu olhar o source do OpenWrt ophub para parametros/DTBs que ja funcionaram em S905W.
- Clone local:
  - `work/ophub-amlogic-s9xxx-openwrt`
  - origem: `https://github.com/ophub/amlogic-s9xxx-openwrt.git`
- Achados no `model_database.conf`:
  - S905W suportado na familia `meson-gxl`.
  - ID 111: `TX3-Mini,MeCool-m8s-pro-W`, DTB `meson-gxl-s905w-tx3-mini.dtb`, u-boot `u-boot-s905x-s912.bin`, boot config `uEnv.txt`, build `yes`.
  - ID 112: `W95`, DTB `meson-gxl-s905w-p281.dtb`, u-boot `u-boot-s905x-s912.bin`, build `no`.
  - ID 113: `X96-Mini`, DTB `meson-gxl-s905w-x96-mini.dtb`, build `no`.
  - ID 114: `X96W/FunTV/MXQ-Pro-4K`, DTB `meson-gxl-s905w-x96w.dtb`, build `no`.
- Interpretacao para o Aquario:
  - `meson-gxl-s905w-p281.dtb` e a pista mais proxima por ser p281 mainline.
  - Para Android 9/vendor Amlogic 4.9, esse DTB mainline nao encaixa diretamente, mas serve como referencia para desligar blocos ausentes/errados: VPU/VPP/BT/TVIN.
- Sobre kernel 4.9 do ophub:
  - `amlogic-s9xxx-openwrt` atual aponta para `ophub/kernel` com tags `stable`, `flippy`, `beta`.
  - documentacao atual fala em `stable/5.x.y` para Amlogic; ainda nao encontrei 4.9 nos refs/tags do repo atual.
  - investigar releases/assets antigas de `ophub/kernel` ou `unifreq/openwrt_packit` pode revelar um pacote 4.9 historico.
- Proximo panic apos desativar VECM:
  - o kernel passou do VECM e morreu em Bluetooth Amlogic:

```text
enter bt_probe of_node
Unable to handle kernel paging request at virtual address fffffffffffffdfb
PC is at desc_to_gpio+0x18/0x3c
LR is at bt_probe+0x2ec/0x520
```

- Causa provavel:
  - `of_get_named_gpiod_flags()` retorna `ERR_PTR(-517)` ou similar por GPIO/pinctrl ausente/deferido.
  - `bt_device.c` chama `desc_to_gpio(desc)` sem checar `IS_ERR(desc)`.
- Proximo teste:
  - `CONFIG_AMLOGIC_BT_DEVICE=n`, porque Bluetooth nao e necessario para chegar no shell.

## 2026-07-21 - Teste apos reinicio: DTB Khadas com fstab Android

- Usuario reiniciou e o prompt voltou para `A95X#`.
- O U-Boot perdeu as variaveis salvas e voltou a:

```text
ipaddr=10.18.9.97
serverip=10.18.9.113
```

- Reapliquei na sessao:

```text
setenv ipaddr 192.168.1.139
setenv serverip 192.168.1.10
```

- Teste TFTP feito com:
  - boot: `boot-khadas-fresh-p281-earlycon-nobt.img`
  - DTB: `gxl_p281_1g_khadas_fstab.dtb`
- Resultado importante:
  - O erro anterior `First stage mount skipped (missing/incompatible fstab in device tree)` desapareceu.
  - O init passou a ler `/proc/device-tree/firmware/android/` corretamente.
  - Novo erro:

```text
partition(s) not found in /sys, waiting for their uevent(s): odm, system, vendor
partition(s) not found after polling timeout: odm, system, vendor
Failed to mount required partitions early ...
Reboot start, reason: reboot, rebootTarget: bootloader
```

- Interpretacao:
  - Agora o gargalo e fstab/particoes, nao kernel panic.
  - O DTB Khadas inclui `vendor` e `odm`, mas o mapa original Aquario usado pelo kernel exposto no boot atual nao fornece essas particoes.
  - Proximo teste: DTB original Aquario + bloco `firmware/android/fstab` contendo inicialmente apenas `/system`.
- Artefato em preparacao:
  - `work/dtb-aquario-android9-fstab-20260721/aquario_original_android9_system_fstab.dts`

## 2026-07-21 - DTB original Aquario com fstab Android system-only

- Criei DTB derivado do DTB original Aquario, adicionando somente:

```dts
firmware {
    android {
        compatible = "android,firmware";
        fstab {
            compatible = "android,fstab";
            system {
                compatible = "android,system";
                dev = "/dev/block/system";
                type = "ext4";
                mnt_flags = "ro,barrier=1";
                fsmgr_flags = "wait";
            };
        };
    };
};
```

- Artefatos:
  - DTS: `work/dtb-aquario-android9-fstab-20260721/aquario_original_android9_system_fstab.dts`
  - DTB: `work/dtb-aquario-android9-fstab-20260721/aquario_original_android9_system_fstab.dtb`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/aquario_original_android9_system_fstab.dtb`
  - SHA256: `2fa71e767cc5fafcb29ccd44495ad0c1a7200e86ee359e29fba386341c451d39`
- Teste TFTP:

```text
tftpboot 0x1080000 boot-khadas-fresh-p281-earlycon-nobt.img
tftpboot 0x1000000 aquario_original_android9_system_fstab.dtb
setenv bootargs
bootm 0x1080000
```

- Resultado:
  - first-stage mount leu o DTB e nao reclamou mais de fstab incompativel.
  - Agora espera somente `system`, como desejado:

```text
init: Using Android DT directory /proc/device-tree/firmware/android/
init: partition(s) not found in /sys, waiting for their uevent(s): system
init: partition(s) not found after polling timeout: system
init: Failed to mount required partitions early ...
```

- Conclusao:
  - O problema atual e que o kernel/DT/layout nao esta expondo uma particao/uevent nomeada `system` para o first-stage init.
  - O DTB Khadas provou que o fstab DT funciona; o DTB Aquario provou que vendor/odm nao eram o unico problema.
  - Proximos caminhos:
    1. ajustar mapa de particoes/driver Amlogic para gerar `/dev/block/system` cedo;
    2. ou patchar/reempacotar init/ramdisk para pular first-stage mount e montar legacy depois;
    3. ou usar device real tipo `/dev/block/mmcblkXpY` se criarmos GPT/particoes no cartao.

## 2026-07-21 - Causa provavel do `/dev/block/system` ausente no SD

- No kernel Khadas/Amlogic 4.9, `drivers/mmc/card/block.c` chama `aml_emmc_partition_ops(card, md->disk)` depois de adicionar o disco MMC.
- Mas em `drivers/amlogic/mmc/emmc_partitions.c`, `aml_emmc_partition_ops()` retorna antes se `is_card_emmc(card) == 0`.
- `is_card_emmc()` aceitava apenas `mmc_hostname(mmc) == "emmc"`.
- No nosso teste o Android esta rodando do cartao SD, e o kernel cria o disco como SD (`mmcblk1` no log), entao a tabela Amlogic/MPT nao e parseada pelo kernel.
- Isso explica o erro do Android 9:

```text
partition(s) not found in /sys: system
```

- Patch de teste aplicado em:
  - `work/khadas-linux-pie-fresh-20260721/drivers/amlogic/mmc/emmc_partitions.c`
- Mudanca:
  - aceitar hostname `sd` alem de `emmc` em `is_card_emmc()`.
  - logs novos:

```text
aml_emmc_partition_ops: allowing host sd
aml_emmc_partition_ops: skipping non-store host <nome>
```

- Objetivo do proximo boot:
  - confirmar se o kernel passa a criar particoes nomeadas `system`, `cache`, `data`, etc a partir da MPT do cartao.

## 2026-07-21 - Teste kernel `sdpart` com DTB Khadas

- Boot testado:
  - kernel/bootimg: `boot-khadas-fresh-p281-earlycon-sdpart.img`
  - DTB: `gxl_p281_1g_khadas_fstab.dtb`
- O DTB Khadas registra o SD corretamente:

```text
mmcblk1: sd:aaaa SC32G 29.7 GiB
meson-mmc: Enter aml_emmc_partition_ops
meson-mmc: aml_emmc_partition_ops: allowing host sd
```

- Novo erro:

```text
meson-mmc: [get_reserve_partition_off] Error, NOT relate to eMMC,"" storage_flag=0
meson-mmc: [aml_emmc_partition_ops] mmc read partition ERROR!
```

- Conclusao:
  - O patch para aceitar SD funcionou.
  - Agora falta ensinar `get_reserve_partition_off()` a retornar o offset da area reserved/MPT tambem quando o host e SD.
  - Enquanto isso nao acontece, as particoes AML nao sao criadas e o Android continua falhando em `system/vendor/odm not found`.

## 2026-07-21 - `sdpart2` criou as particoes tarde demais

- Patch adicional em `get_reserve_partition_off()`:
  - para host `sd`, usar offset AML reserve `0x2400000` (36 MiB).
- Artefato:
  - `work/teste-khadas-fresh-20260721-sdpart2/bootimgs/boot-khadas-fresh-p281-earlycon-sdpart2.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-earlycon-sdpart2.img`
  - SHA256 boot: `b59634e923f60587e95c0b2cfdeb5ef748bb16f480772790d3068cc00284231d`
  - SHA256 Image.gz: `15840ab6b457d82507d3cbd6f4d155e434b0652aa9030d56df251f600f45b987`
- Resultado com DTB Khadas:
  - o kernel leu a tabela MPT/AML do SD e criou as particoes:

```text
get_reserve_partition_off: using SD AML reserve offset 0x2400000
[aml_emmc_partition_ops] mmc read partition OK!
add_emmc_partition
[mmcblk1p16] vendor  offset 0x5d600000 size 0x20000000
[mmcblk1p17] odm     offset 0x7de00000 size 0x08000000
[mmcblk1p18] system  offset 0x86600000 size 0x74000000
[mmcblk1p19] product offset 0xfae00000 size 0x08000000
[mmcblk1p20] data    offset 0x103600000 size 0xcea00000
Exit aml_emmc_partition_ops OK.
```

- Problema restante:
  - Android first-stage init esperou so ~10s e desistiu antes:

```text
init: partition(s) not found in /sys, waiting for their uevent(s): odm, system, vendor
init: Wait for partitions returned after 10003ms
init: Failed to mount required partitions early ...
```

  - As particoes apareceram aos ~50s por retries do SD/MMC (`CMD18`, `CMD13`).
- Proximo passo:
  - aumentar o timeout do first-stage mount/uevent em init ou via fstab se suportado.

## 2026-07-21 - Ramdisk `timeout90` para esperar particoes SD/AML

- Causa provavel do reboot anterior:
  - o kernel criou `vendor`, `odm` e `system` so por volta de 50s, mas o Android first-stage init esperava apenas 10s.
- Patch aplicado em:
  - `infra/aidan/aosp9/system/core/init/init_first_stage.cpp`
- Mudanca:
  - `InitRequiredDevices()` agora espera 90s pelos uevents das particoes obrigatorias.
  - Comentario no codigo indica o motivo: Aquario STV3000 em SD-as-eMMC demora por retries do cartao.
- Rebuild feito dentro do container correto `android9-aquario`:
  - recompilado `libinit` via `out/soong/build.ninja`.
  - religado/copidado `out/target/product/stv3000/root/init` via `out/ninja-aquario_stv3000.sh`.
- Hash do novo `init`:

```text
ed6bbff6afa3a46bb319e4ede6c443059b10bc5912953dd921485127aac90743  out/target/product/stv3000/root/init
```

- Novo ramdisk:
  - `work/teste-khadas-fresh-20260721-sdpart2-timeout90/ramdisks/ramdisk-timeout90.img`
  - SHA256 `4847f0d04e221a9b10d38321816e53c1f610bf93cb8e875647de2691010edf16`
- Novo boot.img:
  - `work/teste-khadas-fresh-20260721-sdpart2-timeout90/bootimgs/boot-khadas-fresh-p281-earlycon-sdpart2-timeout90.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-earlycon-sdpart2-timeout90.img`
  - SHA256 `ee5508fff4fe216eca653850244e85b76d03c3face123d4c08a6cec6ab4d7c81`
- Proximo teste:
  - bootar `boot-khadas-fresh-p281-earlycon-sdpart2-timeout90.img` com `gxl_p281_1g_khadas_fstab.dtb`.
  - Esperado: first-stage init deve continuar esperando ate as particoes aparecerem e tentar montar `system/vendor/odm`.

## 2026-07-21 - Teste `timeout90` montou particoes e revelou system-as-root

- Boot testado:
  - `boot-khadas-fresh-p281-earlycon-sdpart2-timeout90.img`
  - DTB: `gxl_p281_1g_khadas_fstab.dtb`
- Resultado:
  - avancou bastante: `odm`, `system` e `vendor` montaram no first-stage.

```text
init: [libfs_mgr]__mount(source=/dev/block/odm,target=/odm,type=ext4)=0: Success
init: [libfs_mgr]__mount(source=/dev/block/system,target=/system,type=ext4)=0: Success
init: [libfs_mgr]__mount(source=/dev/block/vendor,target=/vendor,type=ext4)=0: Success
```

- Nova falha:

```text
init: Couldn't load property file '/system/etc/prop.default': open() failed: Too many symbolic links encountered
mke2fs: executing /system/bin/mke2fs failed: Too many symbolic links encountered
reboot: Restarting system with command 'recovery'
```

- Analise:
  - a particao `system` da Aidan e `system-as-root`.
  - `debugfs` mostrou `ro.build.system_root_image=true` em `/system/build.prop`.
  - no topo dessa particao existe `etc -> /system/etc`; quando montada em `/system`, isso vira loop `/system/etc -> /system/etc`.
- Correcao preparada:
  - DTB isolado criado em `work/dtb-khadas-p281-systemroot-20260721/`.
  - Alteracao no fstab DT:
    - `system` recebe `mnt_point = "/"`.
    - adicionada entrada `product` para `/dev/block/product`.
  - DTB novo:
    - `work/dtb-khadas-p281-systemroot-20260721/gxl_p281_1g_khadas_fstab_systemroot.dtb`
    - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/gxl_p281_1g_khadas_fstab_systemroot.dtb`
    - SHA256 `495b03530ef908ce833b2e72d56d7205d012c0ecc52630485b1e38fb3872b517`
- Proximo teste:
  - mesmo boot.img `timeout90`, mas com DTB `gxl_p281_1g_khadas_fstab_systemroot.dtb`.

## 2026-07-21 - DTB systemroot funcionou, fstab do ramdisk ainda conflitava

- Teste com:
  - boot: `boot-khadas-fresh-p281-earlycon-sdpart2-timeout90.img`
  - DTB: `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado importante:
  - o parser DT reconheceu `mnt_point = "/"`.
  - first-stage montou `system` como root e tambem montou `odm`, `product`, `vendor`:

```text
dt_fstab: Using a specified mount point / for system
__mount(source=/dev/block/system,target=/,type=ext4)=0: Success
__mount(source=/dev/block/odm,target=/odm,type=ext4)=0: Success
__mount(source=/dev/block/product,target=/product,type=ext4)=0: Success
__mount(source=/dev/block/vendor,target=/vendor,type=ext4)=0: Success
```

- Melhorou:
  - erro de `/system/etc/prop.default` mudou de `Too many symbolic links` para `No such file or directory`, entao o loop principal saiu.
- Problema restante:
  - `init.amlogic.rc` roda `mount_all /fstab.amlogic`.
  - a fstab do ramdisk ainda tentava remontar `/dev/block/system` em `/system` e rodava `check` em `cache/data/tee`.
  - isso ainda acionava `mke2fs` cedo e mantinha erro `Too many symbolic links`.
- Patch aplicado:
  - `infra/aidan/aosp9/device/aquario/stv3000/fstab.amlogic`
  - removida entrada `/dev/block/system /system`.
  - removido `check` de `cache`, `data` e `tee` temporariamente.
- Novo boot.img:
  - `work/teste-khadas-fresh-20260721-systemroot-fstabfix/bootimgs/boot-khadas-fresh-p281-systemroot-fstabfix.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-systemroot-fstabfix.img`
  - SHA256 `0b7ae23212880c0b5a5fae710dda765be1573cab7bdfc47237427ebeaea3aa0a`
- Novo ramdisk:
  - `work/teste-khadas-fresh-20260721-systemroot-fstabfix/ramdisks/ramdisk-systemroot-fstabfix.img`
  - SHA256 `4a52636ca7d1062a3298b536304713ac5ddb05840fc10a8dee6a8ac0d9d1c40b`
- Proximo teste:
  - bootar `boot-khadas-fresh-p281-systemroot-fstabfix.img` com `gxl_p281_1g_khadas_fstab_systemroot.dtb`.

## 2026-07-21 - Teste `systemroot-fstabfix` ainda usa `/init` do system

- Teste:
  - boot: `boot-khadas-fresh-p281-systemroot-fstabfix.img`
  - DTB: `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - particoes AML no SD apareceram cedo.
  - o first-stage esperou os retries de SD e montou:

```text
__mount(source=/dev/block/system,target=/,type=ext4)=0: Success
__mount(source=/dev/block/odm,target=/odm,type=ext4)=0: Success
__mount(source=/dev/block/product,target=/product,type=ext4)=0: Success
__mount(source=/dev/block/vendor,target=/vendor,type=ext4)=0: Success
```

- Ainda reiniciou para recovery:

```text
mke2fs: executing /system/bin/mke2fs failed: No such file or directory
reboot: Restarting system with command 'recovery'
```

- Conclusao:
  - depois que `system` e montado em `/`, o segundo estagio passa a usar arquivos da propria particao `system` da Aidan.
  - portanto, corrigir apenas o ramdisk/boot.img nao basta; precisamos patchar a particao `system`.
- Preparado artefato de system patchado:
  - base: `infra/aidan/data/build_aidan_validado/verificar_system.bin`
  - novo: `work/aidan-systemroot-patched-20260721/system-aidan-systemroot-patched.raw.img`
  - SHA256 `d13d00b71a49b229d745b389fca858a9b32b6892aec71c85f66ac4cd9b42cedb`
- Mudancas dentro da imagem:
  - `/init` substituido pelo init AOSP recompilado:
    - SHA256 do init: `ed6bbff6afa3a46bb319e4ede6c443059b10bc5912953dd921485127aac90743`
  - adicionado `/fstab.amlogic` corrigido:
    - sem remontar `/dev/block/system` em `/system`.
    - sem `check` em `cache/data/tee`.
- Offset da particao `system` no layout AML:
  - bytes: `0x86600000`
  - decimal: `2254438400`
  - tamanho: `0x74000000` (`1946157056` bytes)
- Com o cartao no PC, gravar a system patchada:

```bash
sudo dd if=work/aidan-systemroot-patched-20260721/system-aidan-systemroot-patched.raw.img of=/dev/sdX bs=4M seek=537 conv=fsync,notrunc status=progress
```

- Observacao:
  - `seek=537` com `bs=4M` corresponde a `0x86600000`.
  - confirmar o device com `lsblk` antes; no ultimo check o leitor aparecia como `/dev/sdi`, mas `0B`, sem cartao acessivel no PC.

## 2026-07-21 - System patchada gravada no cartao SD

- O cartao voltou a aparecer como:

```text
/dev/sdi  29.7G STORAGE DEVICE usb disk
```

- Gravada a particao system patchada no offset AML correto:

```bash
sudo dd if=work/aidan-systemroot-patched-20260721/system-aidan-systemroot-patched.raw.img of=/dev/sdi bs=4M seek=537 conv=fsync,notrunc status=progress
```

- Gravacao:
  - bytes escritos: `1048576000` (`1000 MiB`)
  - offset: `0x86600000`
  - device: `/dev/sdi`
- Validacao por readback dos primeiros 64 MiB:

```text
c7ac18988fed7e6dc373e4da58d8fdc45f962a2ce945301dead56127a6e09cc8  system-readback-head-64m.bin
c7ac18988fed7e6dc373e4da58d8fdc45f962a2ce945301dead56127a6e09cc8  system-img-head-64m.bin
```

- Proximo teste:
  - colocar o cartao no aparelho.
  - bootar via TFTP:
    - `boot-khadas-fresh-p281-systemroot-fstabfix.img`
    - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
  - verificar se o segundo estagio passa a usar o `/init` patchado e o `/fstab.amlogic` dentro da system patchada.

## 2026-07-21 - Erro de alinhamento ao gravar system

- Teste TTL apos gravar a system patchada:
  - boot: `boot-khadas-fresh-p281-systemroot-fstabfix.img`
  - DTB: `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Falha:

```text
EXT4-fs (mmcblk1p18): VFS: Can't find ext4 filesystem
init: [libfs_mgr]__mount(source=/dev/block/system,target=/,type=ext4)=-1: Invalid argument
init: Failed to mount '/': Invalid argument
```

- Causa encontrada:
  - o comando anterior usou `bs=4M seek=537`.
  - `0x86600000 / 4MiB = 537.5`, portanto a gravacao com `seek=537` comecou em `0x86400000`, 2 MiB antes do inicio real da particao `system`.
  - A validacao de readback comparou contra o mesmo offset errado, entao validou a gravacao, mas nao o alinhamento da particao.
- Correcao correta:
  - usar bloco de 1 MiB:

```bash
sudo dd if=work/aidan-systemroot-patched-20260721/system-aidan-systemroot-patched.raw.img of=/dev/sdX bs=1M seek=2150 conv=fsync,notrunc status=progress
```

- Porque:
  - `2150 MiB = 2254438400 bytes = 0x86600000`.
  - alternativa equivalente: `bs=512 seek=4403200`.
- Proximo passo:
  - colocar o cartao no PC e regravar a system patchada com `bs=1M seek=2150`.

## 2026-07-21 - System regravada no offset correto

- Cartao no PC confirmado como:

```text
/dev/sdi 29.7G STORAGE DEVICE usb disk
```

- Regravada a system patchada no offset correto:

```bash
sudo dd if=work/aidan-systemroot-patched-20260721/system-aidan-systemroot-patched.raw.img of=/dev/sdi bs=1M seek=2150 conv=fsync,notrunc status=progress
```

- Gravacao:
  - `1000+0 records in`
  - `1000+0 records out`
  - `1048576000 bytes` escritos
  - offset correto: `2150 MiB = 0x86600000`
- Validacao por readback dos primeiros 64 MiB no offset correto:

```text
c7ac18988fed7e6dc373e4da58d8fdc45f962a2ce945301dead56127a6e09cc8  system-readback-head-64m-correct-offset.bin
c7ac18988fed7e6dc373e4da58d8fdc45f962a2ce945301dead56127a6e09cc8  system-img-head-64m-correct-offset.bin
```

- Proximo teste:
  - recolocar o cartao no aparelho.
  - boot TFTP:
    - `boot-khadas-fresh-p281-systemroot-fstabfix.img`
    - `gxl_p281_1g_khadas_fstab_systemroot.dtb`

## 2026-07-21 - Teste com offset correto avancou, falta evitar format de data/cache

- Teste TTL com system regravada no offset correto:
  - boot: `boot-khadas-fresh-p281-systemroot-fstabfix.img`
  - DTB: `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - `system` voltou a montar corretamente em `/`.
  - `odm`, `product`, `vendor` tambem montaram.
- Falha atual:

```text
mke2fs: executing /system/bin/mke2fs failed: No such file or directory
reboot: Restarting system with command 'recovery'
```

- Analise:
  - a fstab ainda tinha `/data` como `encryptable=footer`.
  - como `/data` esta vazia/wiped, `fs_mgr` tenta formatar e chama `/system/bin/mke2fs`.
  - para bring-up, melhor evitar format automatico e deixar o boot continuar mesmo se `cache/data/tee` falharem.
- Patch v2 preparado:
  - `infra/aidan/aosp9/device/aquario/stv3000/fstab.amlogic`
  - `cache`, `data`, `tee` agora usam `wait,nofail`.
  - removido `encryptable=footer` de `/data`.
- System v2:
  - `work/aidan-systemroot-patched-v2-20260721/system-aidan-systemroot-patched-v2.raw.img`
  - SHA256 `4e887feb190794446d0e26df8971bce14ba88060b30da514747ba1659eca1223`
- Boot/ramdisk v2:
  - `work/teste-khadas-fresh-20260721-systemroot-fstabnofail/bootimgs/boot-khadas-fresh-p281-systemroot-fstabnofail.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-systemroot-fstabnofail.img`
  - SHA256 `ced0662bc39aef5236f188b9174ffaf1f65c69820f4693928eaf034128c5d717`
  - ramdisk SHA256 `416eca7e219ad787157609fd9d51e6dfe339cf27a7dbf9997ac203cfd5c0b951`
- Proximo passo:
  - colocar cartao no PC.
  - gravar system v2:

```bash
sudo dd if=work/aidan-systemroot-patched-v2-20260721/system-aidan-systemroot-patched-v2.raw.img of=/dev/sdX bs=1M seek=2150 conv=fsync,notrunc status=progress
```

  - testar via TFTP:
    - `boot-khadas-fresh-p281-systemroot-fstabnofail.img`
    - `gxl_p281_1g_khadas_fstab_systemroot.dtb`

## 2026-07-21 - System v2 gravada no cartao

- Cartao no PC confirmado:

```text
/dev/sdi 29.7G STORAGE DEVICE usb disk
```

- Gravada system v2 no offset correto:

```bash
sudo dd if=work/aidan-systemroot-patched-v2-20260721/system-aidan-systemroot-patched-v2.raw.img of=/dev/sdi bs=1M seek=2150 conv=fsync,notrunc status=progress
```

- Gravacao:
  - `1000+0 records in`
  - `1000+0 records out`
  - `1048576000 bytes` escritos
  - velocidade media `22.5 MB/s`
- Validacao por readback dos primeiros 64 MiB:

```text
91ef44c7301c69c525899ea07ab7729864c2ba622a23e392b152521419a99ad4  system-v2-readback-head-64m.bin
91ef44c7301c69c525899ea07ab7729864c2ba622a23e392b152521419a99ad4  system-v2-img-head-64m.bin
```

- Proximo teste TTL:
  - `boot-khadas-fresh-p281-systemroot-fstabnofail.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`

## 2026-07-21 - Teste TTL apos preformatar cache/data

- Teste valido com cartao no aparelho e boot TFTP:
  - `boot-khadas-fresh-p281-systemroot-fstabnofail.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Avanco confirmado:
  - kernel 4.9.113 sobe.
  - tabela AML no SD aparece completa, incluindo `vendor` em `mmcblk1p16`, `odm` em `mmcblk1p17`, `system` em `mmcblk1p18`, `product` em `mmcblk1p19`, `data` em `mmcblk1p20`.
  - first-stage monta `system` como `/`, `odm`, `product`, `vendor`.
  - second-stage monta `cache` (`mmcblk1p3`), `data` (`mmcblk1p20`) e `tee` (`mmcblk1p15`).
  - nao reiniciou mais em recovery depois que `cache` e `data` foram preformatados como ext4.
- Novo gargalo:
  - Android fica vivo, mas `init` repete `cannot execve` para HALs em `/vendor/bin/hw/`: keymaster, bluetooth, camera, cas, configstore, drm, gatekeeper, graphics allocator/composer.
  - Camera/bluetooth podem ser desativados para bring-up, mas os provaveis bloqueadores reais sao `graphics.allocator`, `graphics.composer`, `configstore` e possivelmente `keymaster/gatekeeper`.
  - HDMI detecta EDID, mas registra `hdmitx: system: cann't get valid mode`; investigar junto com HAL grafico.
- Causa mais provavel encontrada:
  - A `vendor` atualmente no cartao parece ser a minima/errada.
  - `work/tftp-aquario-android9-vendor256-20260721/vendor.raw.img` e `work/tftp-aquario-android9-20260721-2/vendor.raw.img` tem apenas `media.omx`, `configstore` e `cas` em `/bin/hw`.
  - `infra/aidan/data/build_aidan_validado/verificar_vendor.bin` tem todos os binarios que o boot pediu em `/vendor/bin/hw`, incluindo graphics, keymaster, bluetooth, camera, drm e gatekeeper.
- Offset correto da particao `vendor` no layout AML:
  - offset `0x00005d600000` = `1494 MiB`.
  - tamanho `0x000020000000` = `512 MiB`.
- Proximo passo recomendado:
  - colocar cartao no PC.
  - gravar `infra/aidan/data/build_aidan_validado/verificar_vendor.bin` em `/dev/sdX` com `bs=1M seek=1494 conv=fsync,notrunc`.

## 2026-07-21 - TTL invalidado porque cartao estava no PC

- Usuario avisou que o cartao estava no PC, entao o boot TFTP iniciado com `boot-khadas-fresh-p281-systemroot-fstabnofail.img` foi invalido para validar Android.
- Log esperado nesse caso: first-stage init fica esperando particoes `odm`, `product`, `system`, `vendor` em `/sys`, porque a midia nao esta no aparelho.
- Proximo passo local: checar o leitor/`/dev/sdi`; se o cartao aparecer com tamanho real, formatar/escrever `cache` e `data` nos offsets AML corretos e/ou gravar nova imagem com `fs_mgr` de bring-up.

## 2026-07-21 - Cache/data ext4 gravados no cartao

- Cartao no PC confirmado como `/dev/sdi` com 29.7G.
- Criadas imagens ext4 offline:
  - `work/cache-data-ext4-20260721/cache.ext4.img`, tamanho 1120 MiB, label `cache`.
  - `work/cache-data-ext4-20260721/data.ext4.img`, tamanho 3306 MiB, label `data`.
- Gravado no SD-as-eMMC preservando o restante da imagem:

```bash
sudo dd if=work/cache-data-ext4-20260721/cache.ext4.img of=/dev/sdi bs=1M seek=108 conv=fsync,notrunc status=progress
sudo dd if=work/cache-data-ext4-20260721/data.ext4.img of=/dev/sdi bs=1M seek=4150 conv=fsync,notrunc status=progress
```

- Motivo: no boot anterior valido, `system`, `odm`, `product`, `vendor` montaram, mas o segundo estagio do Android chamou `mke2fs` quatro vezes e reiniciou em recovery. Preformatar `cache` e `data` deve evitar o caminho de format/recovery se o problema era particao wiped.
- Proximo teste no aparelho: usar TFTP com `boot-khadas-fresh-p281-systemroot-fstabnofail.img` e `gxl_p281_1g_khadas_fstab_systemroot.dtb`.

## 2026-07-21 - Vendor completa gravada no cartao

- Cartao no PC confirmado como `/dev/sdi` com 29.7G.
- Gravada a vendor completa da Aidan validada:
  - origem: `infra/aidan/data/build_aidan_validado/verificar_vendor.bin`
  - tamanho: 188743680 bytes / 180 MiB
  - SHA256: `c79551f127ed7e50a64a2378f8c0d9c446ea18ce85c8a73d49dd0bee73c4838d`
  - destino: `/dev/sdi`, offset `1494 MiB` (`0x5d600000`), dentro da particao `vendor` de 512 MiB.

```bash
sudo dd if=infra/aidan/data/build_aidan_validado/verificar_vendor.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Motivo: o boot anterior montava uma vendor minima/errada que nao tinha HALs essenciais em `/vendor/bin/hw`, causando repetidos `cannot execve` para graphics allocator/composer, keymaster, gatekeeper etc.
- Proximo teste: recolocar cartao no aparelho e bootar via TFTP com `boot-khadas-fresh-p281-systemroot-fstabnofail.img` + `gxl_p281_1g_khadas_fstab_systemroot.dtb`.

## 2026-07-21 - System v3 debugexec gravada no cartao

- Criada system v3 para diagnosticar `cannot execve` dos HALs de `/vendor/bin/hw`.
- Patch aplicado em `system/core/init/service.cpp`: antes de `execv` de servicos em `/vendor/bin/hw/`, o `init` registra no kmsg/serial `stat()` de:
  - o proprio binario do HAL;
  - `/system`, `/system/bin`, `/system/bin/linker`, `/system/etc/prop.default`;
  - `/vendor`, `/vendor/bin`, `/vendor/bin/hw`, `/vendor/lib`;
  - libs chave em `/vendor/lib` e `/system/lib`.
- Novo `init` rebuilt no container `android9-aquario`:
  - `infra/aidan/aosp9/out/target/product/stv3000/root/init`
  - SHA256 `a9a7274237f8ab81e20b558aa0b78498a183aef47cba3d44ea41246f74394fbb`
- System v3:
  - `work/aidan-systemroot-patched-v3-debugexec-20260721/system-aidan-systemroot-patched-v3-debugexec.raw.img`
  - SHA256 `571abeabf355af18c829a6b18bd0825fb5e1daeb58e3bd5f36795c772c5913ec`
- Gravada no cartao `/dev/sdi` em `system`, offset `2150 MiB`:

```bash
sudo dd if=work/aidan-systemroot-patched-v3-debugexec-20260721/system-aidan-systemroot-patched-v3-debugexec.raw.img of=/dev/sdi bs=1M seek=2150 conv=fsync,notrunc status=progress
```

- Proximo teste: recolocar cartao no aparelho e bootar por TFTP com o mesmo boot/dtb; procurar no serial por `aquario exec probe`.

## 2026-07-21 - Boot debugexec com init no ramdisk

- O teste da system v3 nao mostrou `aquario exec probe`, indicando que os `cannot execve` estavam vindo do `init` do ramdisk do boot TFTP, nao do `/init` dentro da system.
- Criado novo ramdisk a partir de `ramdisk-systemroot-fstabnofail.img`, substituindo `/init` pelo init instrumentado.
- Boot debugexec novo:
  - work: `work/teste-khadas-fresh-20260721-debugexec-ramdisk/bootimgs/boot-khadas-fresh-p281-debugexec-ramdisk.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-debugexec-ramdisk.img`
  - SHA256: `c7c1678a6cf4a882b0862c1215cb4c0fcc81a430e4fd00448d8460a64a627609`
- Proximo teste TTL deve usar esse boot novo com `gxl_p281_1g_khadas_fstab_systemroot.dtb` e procurar `aquario exec probe`.

## 2026-07-21 - Diagnostico system paths e boot compat

- Boot debugexec confirmou a causa dos `cannot execve`:
  - `/vendor/bin/hw/android.hardware.keymaster@3.0-service` existe.
  - `/vendor/bin`, `/vendor/bin/hw` e `/vendor/lib` existem.
  - `/system` existe mas esta vazio no runtime.
  - faltam `/system/bin`, `/system/bin/linker` e `/system/etc/prop.default`.
  - tambem falta `/vendor/lib/libc++.so`; as libs comuns estao na system.
- Conclusao: o problema atual e layout/path de system-as-root; os HALs 32-bit existem, mas o interpreter `/system/bin/linker` nao esta acessivel.
- Criado boot compat com copia no ramdisk de:
  - `/system/bin/linker`
  - `/system/bin/mke2fs`
  - `/system/etc/prop.default`
  - todo `/system/lib` 32-bit
- Boot compat TFTP:
  - `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-systempaths.img`
  - tamanho ~90 MiB
  - SHA256 `0646b59afe24eee4181a531b7f3f7672183e3dd5b94ede0737856fe98ddf8ae3`
- Objetivo do proximo teste: ver se os HALs passam do `cannot execve` ou se aparecem erros de libs mais especificas.

## 2026-07-21 - Boot compat minlibs

- Boot compat com todo `/system/lib` ficou com ~90 MiB e carregou por TFTP, mas o U-Boot falhou em `android_image_need_move`: `malloc ... failed`.
- Gerado conjunto minimo recursivo de libs para HALs principais (`keymaster`, `graphics allocator/composer`, `configstore`, `drm`, `gatekeeper`, `cas`): 48 libs.
- Criado boot menor com:
  - `/system/bin/linker`
  - `/system/bin/mke2fs`
  - `/system/etc/prop.default`
  - libs minimas em `/system/lib`
- Boot TFTP:
  - `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs.img`
  - tamanho ~13 MiB
  - SHA256 `c8dc8b6ce5b09daf6ad7b263ef61ac80cd0b8b1ec896f61f4593cb4c7027755b`

## 2026-07-21 - Boot compat minlibs gravado no SD pelo U-Boot

- Usuario sugeriu gravar o boot no cartao em vez de usar TFTP sempre.
- No U-Boot, `mmc dev 0` acessou o cartao SD corretamente.
- Imagem gravada:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - tamanho `13352960` bytes (`0xcbc000`)
  - setores de 512 bytes: `26080` (`0x65e0`)
- Offset da particao boot no layout Amlogic/Aidan:
  - bytes `0x55c00000`
  - setores `0x2ae000`
- Comandos executados no U-Boot:

```text
tftpboot 0x1080000 boot-khadas-fresh-p281-compat-minlibs.img
mmc dev 0
mmc write 0x1080000 0x2ae000 0x65e0
```

- Resultado:

```text
MMC write: dev # 0, block # 2809856, count 26080 ... 26080 blocks written: OK
```

- Observacao: U-Boot nao tem comando `sync`; `mmc write` retornou OK.

## 2026-07-21 - Boot compat minlibs nobtcam

- Teste por TFTP de `boot-khadas-fresh-p281-compat-minlibs.img` avancou em relacao ao erro anterior:
  - `/system/bin/linker` e `/system/etc/prop.default` agora aparecem no runtime.
  - A falha `cannot execve('/vendor/bin/hw/...'): No such file or directory` deixou de aparecer para os HALs observados.
  - `mke2fs` ainda falhou por falta de `libext2fs.so`.
  - `vendor.bluetooth-1-0` e `vendor.camera-provider-2-4` entram em loop; o aparelho nao tem camera/bluetooth util para o bring-up atual.
- Criada variante:
  - work: `work/teste-khadas-fresh-20260721-compat-minlibs-nobtcam-v2/bootimgs/boot-khadas-fresh-p281-compat-minlibs-nobtcam.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-nobtcam.img`
  - SHA256: `ff1a33b1507c0ae53c894b757b52ed36b3f7b1ea287ff1f8d39882d66d8e3996`
  - tamanho: ~14 MiB
- Mudancas:
  - adicionadas no ramdisk `/system/lib/libext2fs.so`, `libext2_uuid.so`, `libext2_blkid.so`, `libext2_com_err.so`, `libext2_e2p.so`.
  - `init.rc` do ramdisk recebeu parada explicita de `vendor.bluetooth-1-0` e `vendor.camera-provider-2-4`, incluindo gatilhos quando esses servicos entram em `running`.
- Observacao importante:
  - a imagem `compat-minlibs` bootou por TFTP, mas a mesma imagem lida da particao boot do SD gerou SError logo no kernel.
  - Para gravacao final no SD, investigar/aliviar isso zerando/padronizando a particao boot de 16 MiB, lendo tamanho alinhado, ou usando outro endereco de carga.
- Primeiro build `nobtcam` foi gerado por engano com cmdline curta, sem `rootfstype=ramfs init=/init console=ttyAML0,115200`, e morreu cedo logo apos `domain-0 init dvfs: 4`.
- Regerada variante corrigida:
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-nobtcam-cmdfix.img`
  - SHA256: `27a059860251edcc6099d27e6f2c81777f1eae6f8f549be48e37cb9bc92bce2c`
  - cmdline restaurada: `rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug console=ttyAML0,115200`
- Mesmo com cmdline corrigida, `nobtcam-cmdfix` morreu logo apos `domain-0 init dvfs: 4`.
- Diagnostico: ramdisk cresceu para ~5.1 MiB e o U-Boot carregou em `Loading Ramdisk to 33989000, end 33ea010d`, muito perto de `reloc_addr =33ecf350`; forte suspeita de aperto/overlap de memoria no loader.
- Criada variante menor sem libs ext2 adicionais, apenas stop de camera/bluetooth no `init.rc`:
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-stoponly.img`
  - SHA256: `1df599fd885b29a2011f899ec9b63f55c6d2b83a1c17fafdae252a52c57854bb`
  - tamanho: ~13 MiB; ramdisk ~4.9 MiB.
- Teste de controle com a imagem original `boot-khadas-fresh-p281-compat-minlibs.img` confirmou que ela ainda boota e chega ao Android; as variantes mexidas no ramdisk foram a causa do boot morto.
- Decisao: nao colocar mais correcoes de camera/bluetooth/ext2 no ramdisk ate estabilizar; corrigir vendor/system nas particoes.

## 2026-07-21 - Vendor sem camera/bluetooth

- Criada vendor patchada removendo somente:
  - `/vendor/etc/init/android.hardware.bluetooth@1.0-service.rc`
  - `/vendor/etc/init/android.hardware.camera.provider@2.4-service.rc`
- Arquivo:
  - work: `work/vendor-patched-nobtcam-20260721/verificar_vendor-nobtcam.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-nobtcam.bin`
  - SHA256: `4f63308c6c810e84f6c205b3338b4e0c47d3913dabe0082d74aa7e4cc2d49c6f`
  - tamanho: 180 MiB = `0xb400000` bytes = `0x5a000` setores de 512.
- Offset vendor no SD/Aidan:
  - bytes `0x5d600000`
  - setores `0x2eb000`
- Comando U-Boot pretendido:

```text
tftpboot 0x1080000 verificar_vendor-nobtcam.bin
mmc dev 0
mmc write 0x1080000 0x2eb000 0x5a000
```

- Tentativa de gravar os 180 MiB em um unico `mmc write` causou `Synchronous Abort` no U-Boot e resetou:
  - comando: `mmc write 0x1080000 0x2eb000 0x5a000`
  - erro: `Synchronous Abort handler, esr 0x96000010`
- Hipotese: U-Boot antigo instavel com escrita muito grande de uma vez.
- Criados chunks TFTP em:
  - `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/vendor-nobtcam-chunks/vendor-nobtcam.00` ... `.11`
  - 11 chunks de 16 MiB (`0x8000` setores cada) + 1 chunk final de 4 MiB (`0x2000` setores).
- Plano de escrita por partes:

```text
vendor-nobtcam.00 -> setor 0x2eb000, count 0x8000
vendor-nobtcam.01 -> setor 0x2f3000, count 0x8000
vendor-nobtcam.02 -> setor 0x2fb000, count 0x8000
vendor-nobtcam.03 -> setor 0x303000, count 0x8000
vendor-nobtcam.04 -> setor 0x30b000, count 0x8000
vendor-nobtcam.05 -> setor 0x313000, count 0x8000
vendor-nobtcam.06 -> setor 0x31b000, count 0x8000
vendor-nobtcam.07 -> setor 0x323000, count 0x8000
vendor-nobtcam.08 -> setor 0x32b000, count 0x8000
vendor-nobtcam.09 -> setor 0x333000, count 0x8000
vendor-nobtcam.10 -> setor 0x33b000, count 0x8000
vendor-nobtcam.11 -> setor 0x343000, count 0x2000
```

- Usuario colocou o cartao no PC; dispositivo confirmado:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravacao feita pelo PC com `dd`:

```bash
sudo dd if=work/vendor-patched-nobtcam-20260721/verificar_vendor-nobtcam.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo de 180 MiB validado:
  - original SHA256: `4f63308c6c810e84f6c205b3338b4e0c47d3913dabe0082d74aa7e4cc2d49c6f`
  - readback SHA256: `4f63308c6c810e84f6c205b3338b4e0c47d3913dabe0082d74aa7e4cc2d49c6f`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar cartao no aparelho e bootar com `boot-khadas-fresh-p281-compat-minlibs.img` + `gxl_p281_1g_khadas_fstab_systemroot.dtb`; esperado: sumirem os loops de `vendor.bluetooth-1-0` e `vendor.camera-provider-2-4`.

## 2026-07-21 - Teste da vendor nobtcam

- Boot usado:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - A vendor `nobtcam` funcionou: nao aparecem mais probes/loops de `vendor.bluetooth-1-0` nem `vendor.camera-provider-2-4` no boot novo.
  - O loop visivel passou para:
    - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
    - `/vendor/bin/hw/android.hardware.health@2.0-service`
  - `mke2fs` ainda falha por falta de `libext2fs.so` no rootfs minimo:
    - `CANNOT LINK EXECUTABLE "/system/bin/mke2fs": library "libext2fs.so" not found`
  - Em logs antigos, `health@2.0` aborta ao registrar no `hwservicemanager`:
    - `HealthServiceCommon.cpp:56 ... Failed to register HAL`
- Criada vendor incremental removendo tambem health:
  - work: `work/vendor-patched-nobtcam-nohealth-20260721/verificar_vendor-nobtcam-nohealth.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-nobtcam-nohealth.bin`
  - SHA256: `16356e451c3745ed7eb37e1326cb87fef7d1e0482b4fa5e8bc1f71049e7c1081`
  - permanece com graphics allocator/composer.
- Proximo teste recomendado: gravar `verificar_vendor-nobtcam-nohealth.bin` no cartao pelo PC em `seek=1494` e validar readback; evitar gravacao U-Boot da vendor inteira porque ja causou `Synchronous Abort`.

## 2026-07-21 - Vendor nobtcam-nohealth gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor incremental no offset vendor (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-nobtcam-nohealth-20260721/verificar_vendor-nobtcam-nohealth.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo validado:
  - original SHA256: `16356e451c3745ed7eb37e1326cb87fef7d1e0482b4fa5e8bc1f71049e7c1081`
  - readback SHA256: `16356e451c3745ed7eb37e1326cb87fef7d1e0482b4fa5e8bc1f71049e7c1081`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar no aparelho e bootar com `boot-khadas-fresh-p281-compat-minlibs.img` + `gxl_p281_1g_khadas_fstab_systemroot.dtb`; esperado: sumir loop de `health@2.0` e observar se `graphics.composer` ainda reinicia.

## 2026-07-21 - Primeiro boot nobtcam-nohealth invalido

- Boot iniciado com:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- O kernel subiu, mas o teste da vendor ficou invalido porque o host SD perdeu o cartao antes de montar as particoes:
  - first-stage aguardava `odm, product, system, vendor`
  - erros:
    - `meson-mmc: sd: resp_timeout ... cmd:51`
    - `sd: error -110 whilst initialising SD card`
    - depois retries em `cmd:1`
- Interpretacao: problema de inicializacao/contato/timing do SD neste boot, nao evidencia contra a vendor `nobtcam-nohealth`.
- Proximo passo: rebootar e testar novamente; se repetir, reinserir cartao ou reduzir/tunar frequencia/phase do host SD no DTB/kernel.
- Proximo teste: `mmc read 0x1080000 0x2ae000 0x65e0`, carregar DTB e `bootm 0x1080000`.

## 2026-07-21 - TTL depois do boot nobtcam-nohealth

- Segundo boot da vendor `nobtcam-nohealth` foi valido: o Android chegou novamente ao segundo estagio e montou vendor/system.
- Camera, bluetooth e health nao aparecem mais em loop nos probes do init.
- Loops restantes observados no TTL:
  - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
  - `/vendor/bin/hw/android.hardware.light@2.0-service`
- HDMI detecta hotplug/EDID em alguns momentos, mas ainda registra:
  - `hdmitx: system: cann't get valid mode`
  - sem imagem util no HDMI.
- Criada vendor incremental para o proximo teste removendo tambem light:
  - work: `work/vendor-patched-nobtcam-nohealth-nolight-20260721/verificar_vendor-nobtcam-nohealth-nolight.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-nobtcam-nohealth-nolight.bin`
  - SHA256: `f26bc9ff5d6f28816d9aa859bf5cc7674bf9eb4a93a2bae9641202b0cbb3124f`
- Estado atual do PC ao tentar avancar: `/dev/sdi` apareceu como `0B STORAGE DEVICE`; nao gravar nesse estado.
- Proximo passo: quando o cartao enumerar de novo como ~29.7G em `/dev/sdi`, gravar `verificar_vendor-nobtcam-nohealth-nolight.bin` no offset vendor `seek=1494` e validar readback.

## 2026-07-21 - Vendor nobtcam-nohealth-nolight gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor incremental no offset vendor (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-nobtcam-nohealth-nolight-20260721/verificar_vendor-nobtcam-nohealth-nolight.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo validado:
  - original SHA256: `f26bc9ff5d6f28816d9aa859bf5cc7674bf9eb4a93a2bae9641202b0cbb3124f`
  - readback SHA256: `f26bc9ff5d6f28816d9aa859bf5cc7674bf9eb4a93a2bae9641202b0cbb3124f`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar cartao no aparelho e bootar com `boot-khadas-fresh-p281-compat-minlibs.img` + `gxl_p281_1g_khadas_fstab_systemroot.dtb`; esperado: sumir loop de `light@2.0`, restando provavelmente apenas `graphics.composer@2.2` para investigar.

## 2026-07-21 - Teste TTL da vendor nobtcam-nohealth-nolight

- Boot manual por TFTP:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado da vendor:
  - `light@2.0` sumiu do loop.
  - Loops visiveis restantes:
    - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
    - `/vendor/bin/hw/android.hardware.memtrack@1.0-service`
- HDMI:
  - kernel detecta EDID/hotplug e em um ponto escolhe `1920x1080p60hz`:
    - `hdmitx: hdmitx: mode name 1920x1080p60hz`
  - depois ainda aparece:
    - `hdmitx: system: cann't get valid mode`
    - `vout: aml_tvout_mode_work: monitor_timeout`
  - interpretacao: kernel/DTB ja chegam perto de configurar HDMI, mas stack grafico Android ainda nao estabiliza; `graphics.composer` continua sendo o principal bloqueio para UI/SurfaceFlinger.
- Criada vendor incremental removendo tambem memtrack:
  - work: `work/vendor-patched-nobtcam-nohealth-nolight-nomemtrack-20260721/verificar_vendor-nobtcam-nohealth-nolight-nomemtrack.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-nobtcam-nohealth-nolight-nomemtrack.bin`
  - SHA256: `4963da851cf690a123f9b3287d696d8ecf896dfd74c386075ac7d4e2dad862c0`
  - `/etc/init` agora mantem apenas:
    - `android.hardware.graphics.allocator@2.0-service.rc`
    - `android.hardware.graphics.composer@2.2-service.rc`
    - entre os HALs grafico/memoria testados.
- Proximo passo quando cartao voltar ao PC: gravar `nomemtrack` no offset vendor `seek=1494` e validar readback.

## 2026-07-21 - Vendor nobtcam-nohealth-nolight-nomemtrack gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor incremental no offset vendor (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-nobtcam-nohealth-nolight-nomemtrack-20260721/verificar_vendor-nobtcam-nohealth-nolight-nomemtrack.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo validado:
  - original SHA256: `4963da851cf690a123f9b3287d696d8ecf896dfd74c386075ac7d4e2dad862c0`
  - readback SHA256: `4963da851cf690a123f9b3287d696d8ecf896dfd74c386075ac7d4e2dad862c0`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar cartao no aparelho e bootar por TFTP; esperado: sumir loop de `memtrack@1.0` e sobrar `graphics.composer@2.2` como alvo principal.

## 2026-07-21 - Teste TTL da vendor nobtcam-nohealth-nolight-nomemtrack

- Boot manual por TFTP:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - `memtrack@1.0` sumiu do loop.
  - Loops visiveis restantes:
    - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
    - `/vendor/bin/hw/android.hardware.power@1.0-service`
  - HDMI ainda para em `vout: aml_tvout_mode_work: monitor_timeout`.
- Inspecao de `/etc/init` nessa vendor mostrou ainda presentes:
  - `android.hardware.power@1.0-service.rc`
  - `android.hardware.thermal@1.0-service.rc`
  - `android.hardware.tv.cec@1.0-service.rc`
  - `android.hardware.usb@1.0-service.rc`
  - `hdmicecd.rc`
- Criada vendor `min-gfx`, removendo power/thermal/tv.cec/usb/hdmicecd e mantendo so graphics allocator/composer entre esses HALs:
  - work: `work/vendor-patched-min-gfx-20260721/verificar_vendor-min-gfx.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-min-gfx.bin`
  - SHA256: `653a1d70cb881993713f7cd2eaa6b8f6dcea448184e4c27e5bce150acafdc45b`
- Proximo passo quando cartao voltar ao PC: gravar `verificar_vendor-min-gfx.bin` no offset vendor `seek=1494` e validar readback.

## 2026-07-21 - Vendor min-gfx gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor `min-gfx` no offset vendor (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-min-gfx-20260721/verificar_vendor-min-gfx.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo validado:
  - original SHA256: `653a1d70cb881993713f7cd2eaa6b8f6dcea448184e4c27e5bce150acafdc45b`
  - readback SHA256: `653a1d70cb881993713f7cd2eaa6b8f6dcea448184e4c27e5bce150acafdc45b`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar cartao no aparelho e bootar por TFTP; esperado: restar apenas `graphics.composer@2.2` entre os HALs que estavam reiniciando.

## 2026-07-21 - Teste TTL da vendor min-gfx

- Boot manual por TFTP:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - `power`, `thermal`, `tv.cec`, `usb` e `hdmicecd` sumiram do loop.
  - Loops visiveis restantes:
    - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
    - `/vendor/bin/hw/android.hardware.wifi@1.0-service`
- HDMI:
  - no inicio detectou EDID e escolheu `1920x1080p60hz`;
  - depois houve eventos de `plugout`/`plugin` e voltou `hdmitx: system: cann't get valid mode`.
  - ainda nao ha UI no HDMI; `graphics.composer` continua sendo o alvo principal.
- Criada vendor `gfx-only`, removendo tambem Wi-Fi e mantendo so graphics allocator/composer entre os HALs testados:
  - work: `work/vendor-patched-gfx-only-20260721/verificar_vendor-gfx-only.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-only.bin`
  - SHA256: `a462a1d68d3deed329f06c53aab95816de9480bada38c685936d9284ed0f5000`
- Proximo passo quando cartao voltar ao PC: gravar `verificar_vendor-gfx-only.bin` no offset vendor `seek=1494` e validar readback.

## 2026-07-21 - Vendor gfx-only gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor `gfx-only` no offset vendor (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-gfx-only-20260721/verificar_vendor-gfx-only.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo validado:
  - original SHA256: `a462a1d68d3deed329f06c53aab95816de9480bada38c685936d9284ed0f5000`
  - readback SHA256: `a462a1d68d3deed329f06c53aab95816de9480bada38c685936d9284ed0f5000`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar cartao no aparelho e bootar por TFTP; esperado: observar `graphics.composer@2.2` isolado como loop principal.

## 2026-07-21 - Teste TTL da vendor gfx-only

- Boot manual por TFTP:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - `wifi@1.0` sumiu do loop.
  - `graphics.composer@2.2` ficou isolado como loop principal.
  - Probe do init mostrou falta concreta:
    - `init: aquario exec probe missing: /vendor/lib/libc++.so: No such file or directory`
  - `hwcomposer.amlogic.so` tambem depende de `libc++.so`.
- HDMI:
  - novamente detectou EDID e setou `1920x1080p60hz` no inicio;
  - depois ainda caiu em `vout: aml_tvout_mode_work: monitor_timeout`.
- Criada vendor `gfx-only-libcxx`, adicionando `libc++.so` 32-bit do AOSP em `/vendor/lib/libc++.so`:
  - origem da lib: `infra/aidan/aosp9/out/target/product/stv3000/system/lib/libc++.so`
  - work: `work/vendor-patched-gfx-only-libcxx-20260721/verificar_vendor-gfx-only-libcxx.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-only-libcxx.bin`
  - SHA256: `8695e2d24a925c73a27bbc602e05c30747525184dc39a7864dcef4e5e3e8a1a8`
- Proximo passo quando cartao voltar ao PC: gravar `verificar_vendor-gfx-only-libcxx.bin` no offset vendor `seek=1494` e validar readback.

## 2026-07-21 - Vendor gfx-only-libcxx gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor `gfx-only-libcxx` no offset vendor (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-gfx-only-libcxx-20260721/verificar_vendor-gfx-only-libcxx.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo validado:
  - original SHA256: `8695e2d24a925c73a27bbc602e05c30747525184dc39a7864dcef4e5e3e8a1a8`
  - readback SHA256: `8695e2d24a925c73a27bbc602e05c30747525184dc39a7864dcef4e5e3e8a1a8`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar cartao no aparelho e bootar por TFTP; esperado: verificar se o `graphics.composer@2.2` passa da fase de linker sem reclamar de `/vendor/lib/libc++.so`.

## 2026-07-21 - Teste TTL da vendor gfx-only-libcxx

- Boot manual por TFTP:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - `graphics.composer@2.2` continua isolado como loop principal.
  - A falta de `/vendor/lib/libc++.so` foi resolvida:
    - `init: aquario exec probe: /vendor/lib/libc++.so mode=0100755 uid=0 gid=0 size=636324`
  - HDMI ainda para em:
    - `vout: aml_tvout_mode_work: monitor_timeout`
- Analise de dependencias:
  - `hwcomposer.amlogic.so` tambem depende de `libion.so` e `libui.so`.
  - Essas duas libs existiam em `/system/lib`, mas nao em `/vendor/lib`; como o HAL roda em contexto vendor, pode haver restricao/namespace ou busca priorizando vendor.
- Criada vendor `gfx-only-displaylibs`, adicionando:
  - `/vendor/lib/libc++.so`
  - `/vendor/lib/libion.so`
  - `/vendor/lib/libui.so`
  - origem de `libion.so`/`libui.so`: `work/mnt-system-v3-debugexec/system/lib/`
  - work: `work/vendor-patched-gfx-only-displaylibs-20260721/verificar_vendor-gfx-only-displaylibs.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-only-displaylibs.bin`
  - SHA256: `0ae0b7c734b1447c8dc69f34e7d2f159ca4e0f23eaba5e040b6d856857f8e118`
- Proximo passo quando cartao voltar ao PC: gravar `verificar_vendor-gfx-only-displaylibs.bin` no offset vendor `seek=1494` e validar readback.

## 2026-07-21 - Vendor gfx-only-displaylibs gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor `gfx-only-displaylibs` no offset vendor (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-gfx-only-displaylibs-20260721/verificar_vendor-gfx-only-displaylibs.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo validado:
  - original SHA256: `0ae0b7c734b1447c8dc69f34e7d2f159ca4e0f23eaba5e040b6d856857f8e118`
  - readback SHA256: `0ae0b7c734b1447c8dc69f34e7d2f159ca4e0f23eaba5e040b6d856857f8e118`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste: recolocar cartao no aparelho e bootar por TFTP; esperado: verificar se o composer avanca com `libc++`, `libion` e `libui` disponiveis em `/vendor/lib`.

## 2026-07-21 - Teste TTL da vendor gfx-only-displaylibs

- Boot manual por TFTP:
  - `boot-khadas-fresh-p281-compat-minlibs.img`
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`
- Resultado:
  - `graphics.composer@2.2` continua isolado como loop principal.
  - HDMI ainda para em:
    - `vout: aml_tvout_mode_work: monitor_timeout`
  - O probe atual do init so confirma `/vendor/lib/libc++.so`; ele nao checa ainda `libion.so`/`libui.so`, apesar da imagem gravada conter as duas.
- Interpretacao:
  - A fase de linker simples melhorou, mas o erro real do composer ainda nao aparece no log atual.
  - Proximo passo tecnico recomendado: instrumentar mais o init/servico para logar `libion.so`, `libui.so`, `hwcomposer.amlogic.so`, nos de device (`/dev/dri`, `/dev/graphics/fb0`, `/dev/ge2d`) e status/sinal de morte do servico.

## 2026-07-21 - Boot probe-v2 com init mais instrumentado

- Patch aplicado em `infra/aidan/aosp9/system/core/init/service.cpp`:
  - adicionados probes para:
    - `/vendor/lib/libion.so`
    - `/vendor/lib/libui.so`
    - `/vendor/lib/libsync.so`
    - `/vendor/lib/libge2d.so`
    - `/vendor/lib/libamgralloc_ext.so`
    - `/vendor/lib/libhwc2on1adapter.so`
    - `/vendor/lib/libhwc2onfbadapter.so`
    - `/vendor/lib/hw/hwcomposer.amlogic.so`
    - `/vendor/lib/hw/gralloc.amlogic.so`
    - libs graficas/configstore em `/system/lib`
    - `/dev/dri`, `/dev/dri/card0`, `/dev/graphics/fb0`, `/dev/ge2d`, `/dev/ion`
    - `/sys/class/display/mode`, `/sys/class/amhdmitx/amhdmitx0/*`
  - adicionado log em `Service::Reap()` para servicos `/vendor/bin/hw`:
    - `aquario service reap: name=... path=... pid=... code=... status=... uid=...`
- Build do init no container:

```bash
docker exec android9-aquario bash -lc 'cd /workspace/firmware-lab/infra/aidan/aosp9 && source build/envsetup.sh >/dev/null && lunch aquario_stv3000-userdebug >/dev/null && m -j16 init'
```

- Novo init:
  - `infra/aidan/aosp9/out/target/product/stv3000/root/init`
  - SHA256: `11945202333927b0a67ff907f60cf63ec752cea78e2c09e127d6da06b536577d`
- Boot gerado a partir da imagem estavel `compat-minlibs`, mantendo kernel/cmdline e trocando o ramdisk:
  - work: `work/teste-khadas-fresh-20260721-compat-minlibs-probe-v2-234617/bootimgs/boot-khadas-fresh-p281-compat-minlibs-probe-v2.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-probe-v2.img`
  - SHA256: `8eede0abe190933e3021de158df4b8724045c6f210f06af7b0090ec991df8883`
- Proximo teste: bootar por TFTP com `boot-khadas-fresh-p281-compat-minlibs-probe-v2.img` + `gxl_p281_1g_khadas_fstab_systemroot.dtb`.

## 2026-07-21 - Probe-v2 mostrou parada antes da libion

- Teste do `boot-khadas-fresh-p281-compat-minlibs-probe-v2.img` chegou na segunda fase Android e manteve o loop do `android.hardware.graphics.composer@2.2-service`.
- Resultado importante do probe:
  - o init imprime repetidamente ate `/vendor/lib/libc++.so`;
  - nao aparece resultado para `/vendor/lib/libion.so`, que e o proximo item da lista;
  - isso sugere que o filho do servico morre/trava durante ou logo antes de acessar `libion.so`, ou que o log e cortado exatamente nesse ponto.
- HDMI/EDID:
  - o kernel detecta plugin e le EDID (`EDID Parser`, `get PMT vic: 4`), mas o driver `hdmitx` responde `cann't get valid mode`.
  - isso torna HDMI/mode-set um segundo problema real, alem do loop do composer.
- Criado probe-v3 com log antes e depois de cada `stat()`:
  - `aquario exec probe begin: <path>`
  - `aquario exec probe done: <path>`
- Novo init:
  - `infra/aidan/aosp9/out/target/product/stv3000/root/init`
  - SHA256: `ebd659215fec1ef92c861b2371c15b3b58f548ab5d7f3e1e6da2dc81ac8a664f`
- Boot probe-v3:
  - work: `work/teste-khadas-fresh-20260721-compat-minlibs-probe-v3-235059/bootimgs/boot-khadas-fresh-p281-compat-minlibs-probe-v3.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-probe-v3.img`
  - SHA256: `39d8acf7438358616e657d6cccdce09b8b0c6b19aed85a468bd07f42db731502`
- Proximo teste: bootar por TFTP esse probe-v3 e procurar especificamente:
  - `aquario exec probe begin: /vendor/lib/libion.so`
  - `aquario exec probe done: /vendor/lib/libion.so`
  - probes de `/dev/dri`, `/dev/graphics/fb0`, `/dev/ge2d`, `/dev/ion`
  - logs `aquario service reap` do composer.

## 2026-07-21 - Teste probe-v4 e vendor com libsync

- Bootado `boot-khadas-fresh-p281-compat-minlibs-probe-v4.img` por TFTP com DTB `gxl_p281_1g_khadas_fstab_systemroot.dtb`.
- Resultado do probe do composer:
  - presentes:
    - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
    - `/system/bin/linker`
    - `/vendor/lib/libc++.so`
    - `/vendor/lib/libion.so`
    - `/vendor/lib/libui.so`
    - `/vendor/lib/libge2d.so`
    - `/vendor/lib/libamgralloc_ext.so`
    - `/vendor/lib/libhwc2on1adapter.so`
    - `/vendor/lib/libhwc2onfbadapter.so`
    - `/dev/graphics/fb0`
    - `/dev/ge2d`
    - `/dev/ion`
    - `/sys/class/display/mode`
    - `/sys/class/amhdmitx/amhdmitx0`
  - ausentes:
    - `/vendor/lib/libsync.so`
    - `/dev/dri`
    - `/dev/dri/card0`
- Interpretacao atual:
  - Kernel 4.9/Amlogic deste bring-up expoe framebuffer/ge2d/ion, nao DRM; o caminho provavel e usar `libhwc2onfbadapter.so`, nao depender de `/dev/dri/card0`.
  - A ausencia de `/vendor/lib/libsync.so` e a primeira correcao objetiva restante no vendor.
  - HDMI detecta EDID/plug-in repetidamente, mas falha no mode-set com `hdmitx: system: cann't get valid mode` e `vout: aml_tvout_mode_work: monitor_timeout`.
- Criada vendor `gfx-only-displaylibs-sync`, adicionando `/vendor/lib/libsync.so` a partir de `work/mnt-system-v3-debugexec/system/lib/libsync.so`:
  - origem `libsync.so` SHA256: `4cc49b83b698f99bb86da7e3b84da4220d0e9240761b18a5035b8336b50b8e61`
  - work: `work/vendor-patched-gfx-only-displaylibs-sync-20260721/verificar_vendor-gfx-only-displaylibs-sync.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-only-displaylibs-sync.bin`
  - SHA256: `b0d006ab3f831397f5b28abd1e27966aa796ea91e4b590f4028c8e98448196b3`
  - `e2fsck -fn` passou: `vendor: 962/46080 files, 38899/46080 blocks`.
- Tentativa de preparar gravacao no SD:
  - `lsblk` mostrou `/dev/sdi` como `STORAGE DEVICE`, mas tamanho `0B`.
  - Portanto o cartao nao estava acessivel no PC naquele momento; nao foi gravado.
- Proximo passo quando o cartao estiver no PC:
  - confirmar `/dev/sdi` com ~29.7G e sem mountpoint;
  - gravar `verificar_vendor-gfx-only-displaylibs-sync.bin` no offset vendor `seek=1494 MiB`;
  - validar readback SHA256;
  - recolocar no aparelho e bootar probe-v4 novamente.

## 2026-07-22 - Vendor gfx-only-displaylibs-sync gravada no SD

- Cartao no PC confirmado como:
  - `/dev/sdi`, 29.7G, `STORAGE DEVICE`, USB, sem mountpoints.
- Gravada vendor `gfx-only-displaylibs-sync` no offset vendor correto (`seek=1494 MiB`):

```bash
sudo dd if=work/vendor-patched-gfx-only-displaylibs-sync-20260721/verificar_vendor-gfx-only-displaylibs-sync.bin of=/dev/sdi bs=1M seek=1494 conv=fsync,notrunc status=progress
```

- Readback completo de 180MiB validado:
  - original SHA256: `b0d006ab3f831397f5b28abd1e27966aa796ea91e4b590f4028c8e98448196b3`
  - readback SHA256: `b0d006ab3f831397f5b28abd1e27966aa796ea91e4b590f4028c8e98448196b3`
- Executado `sync` e `blockdev --flushbufs /dev/sdi`.
- Proximo teste:
  - recolocar cartao no aparelho;
  - bootar por TFTP `boot-khadas-fresh-p281-compat-minlibs-probe-v4.img` + `gxl_p281_1g_khadas_fstab_systemroot.dtb`;
  - verificar se `/vendor/lib/libsync.so` aparece como presente e se o loop do composer muda.

## 2026-07-22 - Boot probe-v5 para capturar Reap do composer

- Ajustado `infra/aidan/aosp9/system/core/init/service.cpp`:
  - reduziu o probe do composer para menos ruido.
  - `Service::Reap()` agora tambem loga por nome contendo `composer`, `graphics` ou `hwcomposer`, alem de `/vendor/bin/hw/*`.
- Build do init no container `android9-aquario` com `m -j16 init` OK.
- Novo init:
  - SHA256: `7a413517c9fc0f818321a8bad98d622bf94072d8d682407e8db524b7194f5504`
- Boot probe-v5:
  - work: `work/teste-khadas-fresh-20260722-compat-minlibs-probe-v5-000759/bootimgs/boot-khadas-fresh-p281-compat-minlibs-probe-v5.img`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-probe-v5.img`
  - SHA256: `7f0da5dd3997858fac9f4bf5400256582d664c97f5bcd4ddfba870af2b5137c1`
- Proximo teste: bootar probe-v5 com `hdmimode=720p60hz outputmode=720p60hz` e procurar `aquario service reap` do composer.
## 2026-07-22 00:15 - Android 9 Aquario / teste gfx-full-deps

- Log TTL do `boot-khadas-fresh-p281-compat-minlibs-probe-v6.img` com `hdmimode=720p60hz outputmode=720p60hz` confirmou loop do `vendor.hwcomposer-2-2` a cada ~5s:
  - `init: aquario service start: name=vendor.hwcomposer-2-2 path=/vendor/bin/hw/android.hardware.graphics.composer@2.2-service pid=...`
  - probes OK para `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`, `/system/bin/linker`, `/vendor/lib/libc++.so`, `libion.so`, `libui.so`, `libsync.so`, `hwcomposer.amlogic.so`, `gralloc.amlogic.so`.
  - `/dev/dri` e `/dev/dri/card0` ausentes; esperado para caminho fb/ge2d/ion do kernel Amlogic 4.9.
  - Nao apareceu `aquario service reap` do hwcomposer, mas `vendor.media.omx` reapa com `code=1 status=1`, entao a instrumentacao de `Reap()` esta ativa.
- Inspecao da vendor ativa mostrou:
  - `android.hardware.graphics.composer@2.2-service` e 32-bit ARM, interpreter `/system/bin/linker`.
  - rc: `service vendor.hwcomposer-2-2 /vendor/bin/hw/android.hardware.graphics.composer@2.2-service`, `class hal animation`, `user system`, `group graphics drmrpc`, `capabilities SYS_NICE`, `onrestart restart surfaceflinger`.
  - `hwcomposer.amlogic.so` depende tambem de `vendor.amlogic.hardware.systemcontrol@1.0.so` e `@1.1.so`, alem de `libge2d/libion/libui/libsync`.
- Criada nova vendor de teste com dependencias graficas 32-bit adicionais em `/vendor/lib` copiadas de `infra/aidan/aosp9/out/target/product/stv3000/system/lib`:
  - `android.hardware.graphics.composer@2.1.so`
  - `android.hardware.graphics.composer@2.2.so`
  - `android.hardware.graphics.mapper@2.0.so`
  - `libbase.so`, `libbinder.so`, `libcutils.so`, `libfmq.so`, `libhardware.so`
  - `libhidlbase.so`, `libhidltransport.so`, `liblog.so`, `libutils.so`, `libGLESv1_CM.so`
  - desativado `android.hardware.media.omx@1.0-service.rc` para limpar logs.
- Nova imagem:
  - work: `work/vendor-patched-gfx-full-deps-20260722/verificar_vendor-gfx-full-deps.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-full-deps.bin`
  - SHA256: `33cd3fd20051208e75a3b64a466979e10b6e66069ba811f97ac673dbb23d6dcf`
  - `e2fsck -fy` OK: `vendor: 975/46080 files, 39338/46080 blocks`.
- Proximo teste: gravar essa vendor no offset correto do cartao/flash (`seek=1494MiB` ou U-Boot `0x5d600000`) e bootar novamente com probe-v6 + HDMI 720p. Esperado: se o problema era namespace/deps do composer, o loop de 5s muda ou desaparece; se persistir igual, proximo passo e wrapper/diagnostico do binario real do composer.

### 2026-07-22 00:17 - vendor gfx-full-deps gravada no cartao

- Cartao detectado no PC como `/dev/sdi`, 29.7G, modelo `STORAGE DEVICE`, sem particoes montadas.
- Gravada `work/vendor-patched-gfx-full-deps-20260722/verificar_vendor-gfx-full-deps.bin` diretamente no cartao:
  - comando equivalente: `dd if=... of=/dev/sdi bs=1M seek=1494 conv=fsync`
  - readback: `dd if=/dev/sdi of=.../readback-vendor-gfx-full-deps.bin bs=1M skip=1494 count=180`
  - hash esperado e readback iguais: `33cd3fd20051208e75a3b64a466979e10b6e66069ba811f97ac673dbb23d6dcf`
- Proximo passo pratico: colocar o cartao no aparelho, entrar no U-Boot/TTL e bootar `boot-khadas-fresh-p281-compat-minlibs-probe-v6.img` com `gxl_p281_1g_khadas_fstab_systemroot.dtb` e bootargs `hdmimode=720p60hz outputmode=720p60hz`.

## 2026-07-22 00:21 - vendor com wrapper do hwcomposer

- Teste TTL com a vendor `gfx-full-deps` mostrou que a hipotese de dependencias graficas extras em `/vendor/lib` nao bastou:
  - `vendor.hwcomposer-2-2` continuou reiniciando a cada ~5s.
  - `vendor.media.omx` ficou fora do log nessa variante, confirmando que a remocao do rc funcionou e limpou a leitura.
- Criada nova imagem `gfx-wrapper` em cima da `gfx-full-deps`:
  - binario real renomeado para `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service.real`
  - wrapper em `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
  - wrapper escreve no `/dev/kmsg`: inicio, modo atual de `/sys/class/display/mode`, existencia de `fb0/ge2d/ion`, e `exit rc=...` do binario real.
- Imagem:
  - work: `work/vendor-patched-gfx-wrapper-20260722/verificar_vendor-gfx-wrapper.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-wrapper.bin`
  - SHA256: `c54fcdec306a5c360ee5efa4006c7a4c5d1f12357f6779c7d458633c949ef4b9`
  - `e2fsck -fy` OK: `vendor: 976/46080 files, 39339/46080 blocks`.
- Gravada no cartao detectado como `/dev/sdi`, 29.7G, `STORAGE DEVICE`:
  - comando equivalente: `dd if=.../verificar_vendor-gfx-wrapper.bin of=/dev/sdi bs=1M seek=1494 conv=fsync`
  - readback: `dd if=/dev/sdi of=.../readback-vendor-gfx-wrapper.bin bs=1M skip=1494 count=180`
  - hash da imagem e readback iguais: `c54fcdec306a5c360ee5efa4006c7a4c5d1f12357f6779c7d458633c949ef4b9`.
- Proximo teste: colocar cartao no aparelho, entrar no TTL e bootar com probe-v6 + HDMI 720p; procurar linhas `aquario composer-wrapper`.

### 2026-07-22 00:23 - teste wrapper nao pegou no aparelho

- Boot TTL apos gravar `gfx-wrapper` nao mostrou linhas `aquario composer-wrapper`.
- O probe-v6 continuou vendo `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service` com `size=84456`, que e o tamanho do binario original. Se a vendor wrapper estivesse ativa, esse caminho teria tamanho pequeno de script e o binario real estaria em `.real`.
- Tambem reapareceu loop de `vendor.media.omx`, mas esse rc estava desativado nas variantes `gfx-full-deps` e `gfx-wrapper`.
- Interpretacao: o aparelho nao bootou a vendor wrapper gravada em `/dev/sdi`, ou o cartao inserido/testado no aparelho nao corresponde ao dispositivo `/dev/sdi` gravado/validado no PC. Este teste e invalido para avaliar o wrapper.
- Proximo passo correto: recolocar no PC o mesmo cartao que acabou de ir ao aparelho e validar offline:
  - ler 180MiB em `skip=1494` e comparar com SHA256 `c54fcdec306a5c360ee5efa4006c7a4c5d1f12357f6779c7d458633c949ef4b9`;
  - montar a vendor lida e confirmar que `/bin/hw/android.hardware.graphics.composer@2.2-service` e script e que existe `.real`;
  - se nao bater, regravar esse cartao/dispositivo correto.

### 2026-07-22 00:27 - corrigido wrapper para chamada explicita via /system/bin/sh

- Cartao no PC foi validado offline:
  - `/dev/sdi` vendor em `skip=1494 count=180` batia com `gfx-wrapper` SHA256 `c54fcdec306a5c360ee5efa4006c7a4c5d1f12357f6779c7d458633c949ef4b9`.
  - montagem do readback mostrou `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service` como script de 465 bytes, `.real` como ELF 32-bit de 84456 bytes, e `android.hardware.media.omx@1.0-service.rc.disabled`.
- Interpretacao revisada: o cartao estava correto; o Android init provavelmente nao executou o script diretamente como servico HAL, ou nao logou como esperado. Para remover essa ambiguidade, criada variante em que o `.rc` chama explicitamente `/system/bin/sh`.
- Nova imagem:
  - work: `work/vendor-patched-gfx-shwrapper-20260722/verificar_vendor-gfx-shwrapper.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-shwrapper.bin`
  - SHA256: `737c5257a371a2bb65f41bfad1e0a0d900d8aed5e736a80cea07531fbf3548e1`
  - rc do composer: `service vendor.hwcomposer-2-2 /system/bin/sh /vendor/bin/hw/android.hardware.graphics.composer@2.2-service.wrapper`
  - binario real: `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service.real`
  - script: `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service.wrapper`
  - `e2fsck -fy` OK: `vendor: 976/46080 files, 39339/46080 blocks`.
- Gravada em `/dev/sdi`:
  - comando equivalente `dd if=.../verificar_vendor-gfx-shwrapper.bin of=/dev/sdi bs=1M seek=1494 conv=fsync`
  - readback em `skip=1494 count=180` bateu SHA256 `737c5257a371a2bb65f41bfad1e0a0d900d8aed5e736a80cea07531fbf3548e1`.
- Proximo teste: cartao no aparelho, boot probe-v6 + HDMI 720p, procurar `aquario composer-wrapper`.

### 2026-07-22 00:32 - repeticao do teste shwrapper

- Primeiro boot com `gfx-shwrapper` falhou antes do Android segunda fase por erro de leitura do SD:
  - `meson-mmc: sd: resp_timeout`
  - `sd: req failed (CMD18): -110, retrying...`
  - aparelho reiniciou de volta ao U-Boot.
- Repeticao do teste chegou ate segunda fase Android e montou:
  - `system` em `mmcblk1p18`
  - `odm` em `mmcblk1p17`
  - `product` em `mmcblk1p19`
  - `vendor` em `mmcblk1p16`
- Mesmo assim nao apareceram linhas `aquario composer-wrapper`.
- `vendor.media.omx` continuou aparecendo, apesar do rc estar desativado na particao vendor. Investigacao local achou outro rc em `system/vendor/etc/init/android.hardware.media.omx@1.0-service.rc` dentro da particao system usada no bring-up:
  - arquivo fonte ativo: `work/aidan-systemroot-patched-v3-debugexec-20260721/system-aidan-systemroot-patched-v3-debugexec.raw.img`
  - loop montado em `work/mnt-system-v3-debugexec`
- Interpretacao: o ruído de `vendor.media.omx` vem de `system/vendor/etc/init`, nao da particao vendor. Antes de tirar conclusao do wrapper do hwcomposer, limpar esse rc da system para evitar servicos herdados do `system/vendor`.
- Proximo passo: com o cartao no PC, gerar/gravar uma nova system com `system/vendor/etc/init/android.hardware.media.omx@1.0-service.rc` desativado e repetir o boot. Depois, se ainda nao houver wrapper, instrumentar parsing/start do init para `vendor.hwcomposer-2-2`.

### 2026-07-22 00:36 - wrapper corrigido para /vendor/bin/sh

- Cartao no PC:
  - system lida de `/dev/sdi` em `skip=2150 count=1000` montou corretamente, mas nao contem `system/vendor/etc/init/android.hardware.media.omx@1.0-service.rc`.
  - vendor lida de `/dev/sdi` em `skip=1494 count=180` batia com `gfx-shwrapper`, contendo `media.omx.rc.disabled` e `hwcomposer` chamando `/system/bin/sh`.
- Interpretacao revisada:
  - O ruido do `vendor.media.omx` no log nao veio da system readback nem da vendor readback; pode ser log antigo/misturado ou outro caminho de init ainda nao instrumentado.
  - O motivo mais provavel para nao iniciar o wrapper do hwcomposer e o Android init rejeitar/ignorar servico definido em vendor cujo executavel principal e `/system/bin/sh`.
- Criada nova vendor `gfx-vendorsh-wrapper`:
  - copiado `/system/bin/sh` da system do cartao para `/vendor/bin/sh`
  - rc do composer alterado para `service vendor.hwcomposer-2-2 /vendor/bin/sh /vendor/bin/hw/android.hardware.graphics.composer@2.2-service.wrapper`
  - binario real em `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service.real`
  - script wrapper em `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service.wrapper`
  - `android.hardware.media.omx@1.0-service.rc` mantido desativado como `.rc.disabled`
- Imagem:
  - work: `work/vendor-patched-gfx-vendorsh-wrapper-20260722/verificar_vendor-gfx-vendorsh-wrapper.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-vendorsh-wrapper.bin`
  - SHA256: `64e237673d30c51a6a663a341461d436832df504493fedeb3b7f2c639191b2a1`
  - `e2fsck -fy` OK: `vendor: 976/46080 files, 39341/46080 blocks`
- Gravada em `/dev/sdi`:
  - `dd if=.../verificar_vendor-gfx-vendorsh-wrapper.bin of=/dev/sdi bs=1M seek=1494 conv=fsync`
  - readback `skip=1494 count=180` bateu SHA256 `64e237673d30c51a6a663a341461d436832df504493fedeb3b7f2c639191b2a1`.
- Proximo teste: cartao no aparelho, boot probe-v6 + HDMI 720p, procurar `aquario composer-wrapper`. Se ainda nao aparecer, patchar init para logar parse/import de `/vendor/etc/init/android.hardware.graphics.composer@2.2-service.rc`.

### 2026-07-22 00:42 - cleaninit: remover rc desativado de /vendor/etc/init

- Teste com `gfx-vendorsh-wrapper` ainda nao mostrou `aquario composer-wrapper`.
- O `vendor.media.omx` continuou iniciando mesmo com arquivo renomeado para `.rc.disabled`.
- Hipotese corrigida: Android init parseia arquivos dentro de `/vendor/etc/init` independentemente da extensao/sufixo; deixar `.rc.disabled` no mesmo diretorio ainda pode definir o servico.
- Criada nova vendor `gfx-wrapper-cleaninit`:
  - rc do hwcomposer voltou ao caminho original:
    `service vendor.hwcomposer-2-2 /vendor/bin/hw/android.hardware.graphics.composer@2.2-service`
  - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service` agora e script com shebang `#!/vendor/bin/sh`.
  - `/vendor/bin/sh` copiado da system do cartao.
  - binario real em `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service.real`.
  - `android.hardware.media.omx@1.0-service.rc` movido para `/vendor/etc/init.disabled/`, fora de `/vendor/etc/init`.
- Imagem:
  - work: `work/vendor-patched-gfx-wrapper-cleaninit-20260722/verificar_vendor-gfx-wrapper-cleaninit.bin`
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-gfx-wrapper-cleaninit.bin`
  - SHA256: `08f5892519a9e1c40e319f0512e1eb3d880db6e79109575270dc7ea84e101297`
  - `e2fsck -fy` OK: `vendor: 977/46080 files, 39342/46080 blocks`.
- Gravada em `/dev/sdi`:
  - `dd if=.../verificar_vendor-gfx-wrapper-cleaninit.bin of=/dev/sdi bs=1M seek=1494 conv=fsync`
  - readback `skip=1494 count=180` bateu SHA256 `08f5892519a9e1c40e319f0512e1eb3d880db6e79109575270dc7ea84e101297`.
- Proximo teste: cartao no aparelho, boot probe-v6 + HDMI 720p. Esperado: sumir `vendor.media.omx` e aparecer `aquario composer-wrapper`; se nao aparecer, o init precisa ser instrumentado para logar parse/import/start de `vendor.hwcomposer-2-2`.

### 2026-07-26 - retomada com ether8/VRF para TFTP

- Retomada apos mudanca de rede: Android box/A95X esta conectado na ether8 do Mikrotik 192.168.1.254.
- Usado `invade` via Docker (`docker compose run --rm router-analyzer`) para consultar o Mikrotik.
- ether8 esta na VRF `mr80x-recovery`, com endereco do roteador `192.168.1.2/24`.
- Regras TFTP no Mikrotik: pedido UDP para `192.168.1.2:69` vindo da ether8 e marcado como `mr80x-tftp` e dstnat para workstation `192.168.1.10:69`; respostas sao roteadas de volta para `mr80x-recovery`.
- Portanto, no U-Boot do A95X usar `ipaddr=192.168.1.139`, `serverip=192.168.1.2`, `gatewayip=192.168.1.2`, nao `serverip=192.168.1.10` direto.
- Estado TTL confirmado: prompt `A95X#`; env antigo ainda tinha `ipaddr=10.18.9.97` e `serverip=10.18.9.113`.

### 2026-07-26 - TFTP via VRF validado e probe-v7 inittrace

- Teste TFTP no A95X com nova topologia funcionou usando `ipaddr=192.168.1.139`, `serverip=192.168.1.2`, `gatewayip=192.168.1.2`.
- Arquivos carregados por TFTP: `boot-khadas-fresh-p281-compat-minlibs-probe-v6.img` (13340672 bytes) e `gxl_p281_1g_khadas_fstab_systemroot.dtb` (56953 bytes).
- Boot v6 chegou novamente ao kernel 4.9.113 e Android segunda fase; montou `/`, `/odm`, `/product`, `/vendor`, cache/data/tee.
- HDMI ainda ficou ruim no inicio: `vout: refresh_tvout_mode: mode chang to invalid`, `vout: new mode invalid set ok`, depois `vout: aml_tvout_mode_work: monitor_timeout`, apesar de bootargs com `hdmimode=720p60hz outputmode=720p60hz`.
- Log filtrado nao mostrou `aquario composer-wrapper` nem `vendor.hwcomposer`; portanto foi criado patch de instrumentacao do Android init para logar parse/import de rc e todo start/reap de servico.
- Arquivos AOSP alterados: `system/core/init/parser.cpp`, `import_parser.cpp`, `service.cpp`.
- Compilado `bootimage` no container `android9-aquario` com sucesso; substituido apenas `/init` no ramdisk v6 para preservar minlibs.
- Nova imagem TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-probe-v7-inittrace.img`, SHA256 `057f56f66a16571d45342c6c1673bed7027e7bb0d3dca11a2e2fc1061df80998`.
- Proximo teste: reiniciar para U-Boot e bootar `probe-v7-inittrace` com o mesmo DTB e bootargs; procurar prefixos `aquario init parse`, `aquario service parsed`, `aquario service start requested`, `aquario service start`, `aquario service reap`.

### 2026-07-26 - probe-v7 identificou loop do vndservicemanager

- Bootado `boot-khadas-fresh-p281-compat-minlibs-probe-v7-inittrace.img` por TFTP com `serverip=192.168.1.2`.
- TFTP OK: boot 13344768 bytes, DTB 56953 bytes.
- HDMI melhorou no kernel neste boot: `vout: refresh_tvout_mode: mode chang to 720p60hz`, `hdmitx: system: get current mode: 720p60hz`, `vout: new mode 720p60hz set ok`. Ainda ha instabilidade EDID/DDC e eventos plugout/plugin depois.
- Android segunda fase iniciou, mas antes de hwcomposer o gargalo atual e `vndservicemanager`: loop a cada ~5s. Logs v7 mostram `aquario service start requested/start/reap` para `vndservicemanager`, sempre `status=1`.
- Kernel config tem binder OK: `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` e `ashmem` inicializa.
- Como init fecha stdout/stderr dos servicos, criado wrapper para `/vendor/bin/vndservicemanager`:
  - ELF original movido para `/vendor/bin/vndservicemanager.real`
  - script novo registra em `/dev/kmsg` os nodes `/dev/binder`, `/dev/hwbinder`, `/dev/vndbinder`, linkers e stderr/stdout do binario real.
- Nova vendor: `work/vendor-patched-vndsvc-wrapper-20260726/verificar_vendor-vndsvc-wrapper.bin`
- TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/verificar_vendor-vndsvc-wrapper.bin`
- SHA256: `8480def31f54d196bc5577b5302e80cfc53085cc854801ed76e5b599034b6b2d`
- Proximo passo: voltar para U-Boot, gravar essa vendor no offset/particao vendor e bootar probe-v7 de novo.

### 2026-07-26 - confirmacao do usuario sobre cartao

- Usuario confirmou que este Android esta rodando puramente no cartao de memoria usado como eMMC.
- Portanto, testes destrutivos atuais afetam o cartao; para operacoes pesadas/offline e melhor pedir para inserir o cartao no PC.
- Uma tentativa de gravar `verificar_vendor-vndsvc-wrapper.bin` por TFTP estava em andamento, mas o usuario reiniciou; considerar a transferencia/gravação interrompida e repetir/validar antes de assumir que a vendor foi aplicada.

### 2026-07-26 - vendor vndservicemanager wrapper gravada no cartao pelo PC

- Cartao detectado no PC como `/dev/sdg`, 29.7G, modelo `STORAGE DEVICE`, sem particoes montadas.
- Gravada vendor wrapper direto no cartao: `dd if=work/vendor-patched-vndsvc-wrapper-20260726/verificar_vendor-vndsvc-wrapper.bin of=/dev/sdg bs=1M seek=1494 conv=fsync`.
- Readback: `dd if=/dev/sdg of=work/vendor-patched-vndsvc-wrapper-20260726/readback-vendor-vndsvc-wrapper-from-card.bin bs=1M skip=1494 count=180`.
- SHA256 gravado/readback bateu: `8480def31f54d196bc5577b5302e80cfc53085cc854801ed76e5b599034b6b2d`.
- Proximo teste: colocar cartao no aparelho e bootar `boot-khadas-fresh-p281-compat-minlibs-probe-v7-inittrace.img` + `gxl_p281_1g_khadas_fstab_systemroot.dtb` por TFTP. Procurar `aquario vndservicemanager-wrapper` para revelar erro real do `vndservicemanager`.

### 2026-07-26 - boot com vendor vndsvc wrapper no aparelho

- Cartao recolocado no aparelho e bootado por TFTP com `boot-khadas-fresh-p281-compat-minlibs-probe-v7-inittrace.img` e DTB `gxl_p281_1g_khadas_fstab_systemroot.dtb`.
- TFTP OK usando `serverip=192.168.1.2`.
- Kernel setou HDMI 720p: `vout: new mode 720p60hz set ok`; ainda aparecem timeout/EDID em alguns momentos.
- Aguardando/filtrando logs para confirmar se `/vendor/bin/vndservicemanager` wrapper aplicado aparece como `aquario vndservicemanager-wrapper`.

### 2026-07-26 - descoberta: init de segunda fase vem da system

- Boot com vendor wrapper aplicada nao mostrou `aquario vndservicemanager-wrapper` nem logs `aquario service start` no trecho novo.
- Interpretacao corrigida: no layout system-as-root, o `/init` instrumentado no ramdisk/boot executa apenas primeira fase; depois a particao `system` e montada como `/` e o Android executa `/init` de `mmcblk1p18`.
- Evidencia no log: audit aponta `path="/init" dev="mmcblk1p18" ino=25`, ou seja, o init ativo da segunda fase vem da particao system.
- Portanto, para instrumentar starts/reaps e ver o wrapper corretamente, precisa substituir tambem `/init` dentro da particao system do cartao pelo init compilado em `infra/aidan/aosp9/out/target/product/stv3000/root/init`.
- Proximo passo: pedir cartao no PC e editar a system no offset 2150MiB (`mmcblk1p18`, size 1000MiB), preservando o resto.

### 2026-07-26 - init instrumentado instalado na system do cartao

- Cartao confirmado no PC como `/dev/sdg`, 29.7G, modelo `STORAGE DEVICE`, sem particoes montadas. Sempre repetir `lsblk` porque a letra pode mudar.
- Feito backup integral dos 1000MiB da particao system, lida diretamente do offset 2150MiB:
  - arquivo: `work/system-inittrace-20260726/system-before-inittrace-from-card.raw.img`
  - SHA256: `571abeabf355af18c829a6b18bd0825fb5e1daeb58e3bd5f36795c772c5913ec`
  - filesystem ext2/ext4 compativel, label `system`; `e2fsck -fn` sem erros.
- `/init` original da system preservado separadamente:
  - arquivo: `work/system-inittrace-20260726/init.original-from-card`
  - tamanho: 1504180 bytes
  - SHA256: `a9a7274237f8ab81e20b558aa0b78498a183aef47cba3d44ea41246f74394fbb`
- Substituido somente `/init` dentro da system pelo init AOSP instrumentado compilado em `infra/aidan/aosp9/out/target/product/stv3000/root/init`:
  - tamanho: 1504264 bytes
  - modo/dono: `0755 root:root`
  - SHA256 no fonte e na remontagem do cartao: `680442c7e8bb594f251d84a5ac11f0d84f75d5b0306fca783f8efa61b0fd0eaa`
  - strings confirmadas: `aquario init parse file`, `aquario init parse dir`, `aquario service start requested`, `aquario service reap`.
- Validacao final: cartao remontado em read-only, hash conferido e `e2fsck -fn` executado diretamente sobre loop no offset da system, sem erros. Nenhum mount ou loop ficou associado a `/dev/sdg`; cartao liberado para o aparelho.

### 2026-07-26 - estado do bring-up e o que falta para Android funcional

- Ja funciona:
  - U-Boot e TFTP pela ether8/VRF usando box `192.168.1.139`, servidor U-Boot `192.168.1.2` e NAT ate workstation `192.168.1.10`.
  - kernel 4.9.113 AArch64 sobe, reconhece o SD como `mmcblk1`, interpreta a tabela Amlogic e monta system/vendor/odm/product/cache/data/tee.
  - Android chega a `init second stage started` usando system-as-root.
  - HDMI e programado em `720p60hz`, EDID chega a ser lido e o kernel registra `plugin`.
- Bloqueio principal observado antes desta troca:
  - `vndservicemanager` inicia e morre imediatamente com `code=1 status=1`, repetindo a cada ~5 segundos.
  - sem `vndservicemanager` estavel, HALs vendor, hwcomposer e a pilha grafica nao conseguem completar o registro; isso explica Android sem interface e TTL sem shell interativo normal.
  - a vendor atual contem wrapper em `/vendor/bin/vndservicemanager` e ELF real em `.real`, mas faltava instrumentar o init da system para observar a segunda fase correta.
- Proximo teste decisivo:
  - colocar o cartao no aparelho e bootar por TFTP `boot-khadas-fresh-p281-compat-minlibs-probe-v7-inittrace.img` com `gxl_p281_1g_khadas_fstab_systemroot.dtb`.
  - filtrar TTL por `aquario init`, `aquario service`, `aquario vndservicemanager-wrapper`, `vndservicemanager`, `hwservicemanager`, `composer` e `surfaceflinger`.
  - o log deve revelar se o wrapper e rejeitado pelo contexto/exec do init, se `/vendor/bin/sh` falha, se falta linker/biblioteca, ou se o ELF real rejeita `/dev/vndbinder`.
- Depois de estabilizar binder/vendor service manager:
  - fazer `hwservicemanager` e HAL graphics composer permanecerem ativos;
  - confirmar `surfaceflinger` e boot animation, corrigindo dependencias/RCs/labels da vendor conforme o log;
  - corrigir os contextos SELinux incompatíveis de `sysfs_amhdmitx`/`sysfs_hdmi` e depois voltar de permissive para enforcing somente no fim do bring-up;
  - estabilizar HDMI DDC/EDID, que ainda mostra `ddc timeout`, leituras divergentes e checksum invalido apesar de 720p ser configurado;
  - corrigir `/system/bin/mke2fs` sem `libext2fs.so`; e um defeito real de userspace, mas nao parece ser o bloqueio inicial porque cache/data ja montam;
  - limpar RCs/HALs de hardware ausente (camera, bluetooth e outros) apenas para reduzir reinicios e ruido; nao sao a causa primaria atual.

### 2026-07-26 - primeiro boot com init instrumentado dentro da system

- Cartao recolocado no aparelho e reconhecido no U-Boot como SC32G de 29.7GiB.
- Boot e DTB carregados com sucesso por TFTP via `192.168.1.2`:
  - `boot-khadas-fresh-p281-compat-minlibs-probe-v7-inittrace.img`, 13344768 bytes.
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`, 56953 bytes.
- Kernel 4.9.113 subiu, montou `system` (`mmcblk1p18`), `odm`, `product` e `vendor`; Android chegou a `init second stage started`.
- A substituicao do `/init` da system foi confirmada no aparelho: `ueventd` emitiu os novos marcadores `aquario init parse file` para `/ueventd.rc`, `/vendor/ueventd.rc` e `/odm/ueventd.rc`.
- HDMI foi configurado em 1280x720p60 e houve leitura completa de EDID e evento `plugin`; ainda ocorreu `ddc timeout`, diferenca entre leituras/checksum invalido e `monitor_timeout` em 12.46s.
- Neste boot o log serial parou depois de `monitor_timeout` e nao mostrou o loop anterior de `vndservicemanager`, nem ADB, ping ou rede em `192.168.1.139`.
- O sistema chegou a iniciar HALs de keymaster/audio/CAS por volta de 7s, mas nao emitiu os marcadores de start/reap do init principal esperados; precisa diagnostico offline/console para separar supressao de log de bloqueio durante a sequencia de classes do init.
- Decisao: usuario prefere recolocar o cartao no PC. Proxima edicao deve criar uma via de shell serial precoce e/ou ajustar a definicao do wrapper do `vndservicemanager` diretamente na system/vendor, validando tudo offline antes do novo boot.

### 2026-07-26 - console serial precoce e wrapper vndservicemanager corrigido no cartao

- Cartao novamente confirmado como `/dev/sdg`, 29.7G, `STORAGE DEVICE`, sem mounts.
- Inspecao offline confirmou a causa provavel do wrapper silencioso:
  - `/vendor/bin/vndservicemanager` era script de 464 bytes sem xattr SELinux (`?`).
  - `/vendor/bin/vndservicemanager.real` preservava `u:object_r:vndservicemanager_exec:s0`.
  - `/vendor/bin/sh` tem `u:object_r:vendor_shell_exec:s0`.
  - o servico antigo executava diretamente o script sem `seclabel`, deixando `init` calcular contexto a partir de arquivo sem label.
- Backups individuais preservados em `work/card-debug-shell-20260726/`:
  - `vndservicemanager.rc.before`, SHA256 `73067e8623d55dd3517edefb3cb520315fdb7edcc193aec5c3f2785c81b7f350`.
  - `vndservicemanager.wrapper.before`, SHA256 `05cc2443aeec5376840ec09b3f706638b09e59881e1abd4941eb97657e84cf65`.
- Instalado `/system/system/etc/init/aquario-debug.rc`:
  - define `aquario_console /system/bin/sh`, classe core, root, `console ttyAML0`, `seclabel u:r:shell:s0` e PATH completo.
  - deve fornecer prompt root interativo no mesmo TTL assim que `class core` iniciar, reiniciando apos saida.
  - label offline `u:object_r:system_file:s0`, SHA256 `9f82d75dffb479fc54183606410473b508234d887a0416388122402563483f7d`.
- Corrigido `/vendor/etc/init/vndservicemanager.rc`:
  - agora executa `/vendor/bin/sh /vendor/bin/vndservicemanager.wrapper /dev/vndbinder`.
  - fixa `seclabel u:r:vndservicemanager:s0`, eliminando calculo de contexto baseado no script sem label.
  - label `u:object_r:vendor_configs_file:s0`, SHA256 `e19ebe8a6be459361f8bd4cb18407143581b9896c222e94e9449464694139cf5`.
- Instalado `/vendor/bin/vndservicemanager.wrapper` separado:
  - registra PID/args/id, labels dos tres nodes binder, linker, shell e ELF real; depois executa `.real` e registra o retorno.
  - label `u:object_r:vendor_shell_exec:s0`, SHA256 `770d0a345b09634b7436e7f98beed839157269d7abfc4c8007b169ff1b4e2f44`.
- Validacao final offline:
  - `system`: `e2fsck -fn` sem erros, 2419/64000 arquivos, 219589/256000 blocos.
  - `vendor`: `e2fsck -fn` sem erros, 979/46080 arquivos, 39344/46080 blocos.
  - nenhum mount ou loop ficou associado a `/dev/sdg`; cartao liberado para novo boot.

### 2026-07-26 - teste do console e wrapper corrigido

- Novo boot TFTP completou kernel e Android segunda fase; `system`, `vendor`, `odm`, `product`, cache/data/tee montaram novamente.
- O novo `vndservicemanager.rc` da vendor foi comprovadamente aplicado:
  - audit mostra PID 2609 com `comm="sh"`, executando `/vendor/bin/sh` em `scontext=u:r:vndservicemanager:s0`.
  - init passou a registrar `name=vndservicemanager path=/vendor/bin/sh`.
  - portanto a chamada explicita e o `seclabel` funcionaram.
- O shell do wrapper ainda encerra rapidamente com `status=1` e nenhum prefixo do wrapper aparece.
- Causa mais provavel e coerente com o script: a primeira instrucao `exec >/dev/kmsg 2>&1` falha ao abrir `/dev/kmsg`; como e `exec` sem comando, a falha encerra o shell antes de chamar `vndservicemanager.real`.
- O `aquario_console` instalado em `/system/system/etc/init` nao iniciou nem apareceu nos logs; neste layout a importacao efetiva dessa arvore nao esta garantida. A vendor, por outro lado, esta comprovadamente sendo parseada porque o rc alterado do vndservicemanager entrou em vigor.
- Proxima correcao offline:
  - remover redirecionamento global para `/dev/kmsg`; logar individualmente em `/dev/ttyAML0` sem deixar falha de log abortar o script.
  - instalar o servico `aquario_console` tambem em `/vendor/etc/init/aquario-console.rc`, executando `/vendor/bin/sh`, `console ttyAML0`, root e `seclabel u:r:shell:s0`.
  - repetir boot e usar o prompt root para executar o ELF real e inspecionar binder/HALs.

### 2026-07-26 - console movido para vendor e wrapper logando no TTL

- Cartao confirmado novamente como `/dev/sdg`, 29.7G, sem mount.
- Instalado `/vendor/etc/init/aquario-console.rc`:
  - servico `aquario_console /vendor/bin/sh`, classe core, root, `console ttyAML0`, `seclabel u:r:shell:s0` e PATH completo.
  - colocado na arvore vendor comprovadamente parseada pelo init.
  - label `u:object_r:vendor_configs_file:s0`, SHA256 `db1bca5297136b3c2d1974ca080c096b58378125cb51b1005941f5db9a684519`.
- Wrapper anterior preservado em `work/card-debug-shell-20260726/vndservicemanager.wrapper.kmsg.before`, SHA256 `770d0a345b09634b7436e7f98beed839157269d7abfc4c8007b169ff1b4e2f44`.
- `/vendor/bin/vndservicemanager.wrapper` refeito:
  - nao usa mais `exec >/dev/kmsg`, que encerrava o shell quando a abertura falhava.
  - cada log tenta `/dev/ttyAML0` individualmente com `|| true`; falha de log nao impede a execucao do ELF real.
  - executa `vndservicemanager.real` com stdio normal e sempre registra o retorno no TTL quando possivel.
  - label `u:object_r:vendor_shell_exec:s0`, SHA256 `a1cdea151d3daf61d65ac849a85081bcbc8fb6b159ccaac59e42a6bb0715319c`.
- `sh -n` do wrapper passou; vendor passou `e2fsck -fn` sem erros (980/46080 arquivos, 39345/46080 blocos).
- Nenhum mount ou loop ficou associado ao cartao; pronto para novo teste.

### 2026-07-26 - teste do wrapper TTL e console na vendor

- Novo boot TFTP chegou novamente a Android segunda fase e montou todas as particoes esperadas.
- `vndservicemanager` continua sendo iniciado pelo `/vendor/bin/sh` e encerrando em cerca de 35ms com `status=1`.
- Nenhum texto do wrapper chegou ao `ttyAML0`; logo o script falha antes/durante as primeiras operacoes ou o dominio nao consegue abrir o dispositivo, apesar de permissive.
- O novo arquivo `/vendor/etc/init/aquario-console.rc` tambem nao gerou start/reap nem prompt. Embora o AOSP `LoadBootScripts()` normalmente percorra todo `/vendor/etc/init`, neste conjunto efetivo os arquivos novos nao estao produzindo servicos observaveis; o arquivo antigo `vndservicemanager.rc`, por outro lado, e comprovadamente aplicado em todo boot.
- Proxima estrategia: editar temporariamente o proprio `vndservicemanager.rc` conhecido para executar `/vendor/bin/sh` como root com `console ttyAML0` e `seclabel u:r:shell:s0`. Isso deve fornecer shell garantido no lugar do servico em loop.
- No shell, executar manualmente `/vendor/bin/vndservicemanager.real /dev/vndbinder`, inspecionar retorno, linker, bibliotecas, binder, processos e propriedades. Depois restaurar/corrigir o rc definitivo.

### 2026-07-26 - vndservicemanager temporariamente convertido em console root

- Cartao confirmado como `/dev/sdg`, 29.7G, sem mount.
- O rc com wrapper foi preservado em `work/card-debug-shell-20260726/vndservicemanager.rc.wrapper-before-console`, SHA256 `e19ebe8a6be459361f8bd4cb18407143581b9896c222e94e9449464694139cf5`.
- `/vendor/etc/init/aquario-console.rc` foi movido para `/vendor/etc/init.disabled/aquario-console.rc` para evitar dois shells concorrendo pelo TTL.
- `/vendor/etc/init/vndservicemanager.rc` agora e temporariamente um console de diagnostico:
  - executavel `/vendor/bin/sh` sem script intermediario;
  - `class core`, `console ttyAML0`, usuario root, grupos root/shell/system/log/readproc;
  - `seclabel u:r:shell:s0`, HOME e PATH definidos.
  - label do rc `u:object_r:vendor_configs_file:s0`, SHA256 `7ed92de75d6db25fed45550305f34e83f0d2ac58c25be9c1b1535a949c428f8f`.
- Vendor passou `e2fsck -fn` sem erros (980/46080 arquivos, 39345/46080 blocos); nenhum mount/loop restante.
- Proximo boot deve mostrar `vndservicemanager path=/vendor/bin/sh` com uid/gid 0 e manter o shell aberto no TTL. Executar manualmente o ELF real e coletar diagnostico antes de restaurar o rc.

### 2026-07-26 - console direto via flag `console` nao iniciou

- Houve reconexao USB do adaptador durante o teste: o device mudou de `/dev/ttyUSB0` para `/dev/ttyUSB1`; `version` confirmou que o alvo continuava sendo o U-Boot Amlogic 2015.01 da A95X.
- TFTP e boot foram repetidos com sucesso. Android chegou a segunda fase e classe core, mas o `vndservicemanager` temporario nao gerou nem `start requested` nem prompt.
- O kernel continua registrando `Warning: unable to open an initial console`; a flag de servico `console ttyAML0` faz `Service::Start()` tentar abrir o node antes do fork e desabilitar o servico se falhar.
- Como nao houve sequer o marcador `aquario service start requested` para esse rc, a combinacao atual tambem pode estar sendo rejeitada/suprimida durante parse/start; em qualquer caso, depender da flag `console` nao e robusto neste build.
- Proxima variante:
  - remover completamente a flag `console` do rc conhecido.
  - iniciar um script root comum (que init consegue executar com stdio em `/dev/null`).
  - o script verifica em runtime `/dev/ttyAML0`, `/dev/console` e `/dev/ttyS0`; ao achar um char device, faz `exec /vendor/bin/sh <device >device 2>&1`.
  - assim a checagem prematura de console do init e evitada e o proprio shell escolhe o node realmente existente.

### 2026-07-26 - console probe sem flag `console` instalado

- Cartao confirmado como `/dev/sdg`, 29.7G, sem mount.
- Rc temporario anterior preservado em `work/card-debug-shell-20260726/vndservicemanager.rc.console-before-probe`, SHA256 `7ed92de75d6db25fed45550305f34e83f0d2ac58c25be9c1b1535a949c428f8f`.
- Instalado `/vendor/bin/aquario-console-probe`:
  - iniciado como script normal, sem flag `console` no init.
  - fica procurando char devices na ordem `/dev/ttyAML0`, `/dev/console`, `/dev/ttyS0`.
  - ao encontrar um, faz `exec /vendor/bin/sh` com stdin/stdout/stderr ligados diretamente ao device.
  - label `u:object_r:vendor_shell_exec:s0`, SHA256 `d04f4d1b395fcead3e2d0163851375851b01d7c095ec73e6b702df49c4588339`; `sh -n` OK.
- `/vendor/etc/init/vndservicemanager.rc` agora chama `/vendor/bin/sh /vendor/bin/aquario-console-probe` como root, classe core, `seclabel u:r:shell:s0`, sem flag `console`.
  - label `u:object_r:vendor_configs_file:s0`, SHA256 `b0ae14919d6ec531ddde63d6809e361a7877e08eed62966cc4465574c91f4da7`.
- Vendor passou `e2fsck -fn` sem erros (981/46080 arquivos, 39346/46080 blocos); cartao sem mounts/loops e liberado.

### 2026-07-26 - resultado do console probe dinamico

- No boot seguinte, o rc temporario foi aplicado e o init iniciou `/vendor/bin/sh /vendor/bin/aquario-console-probe` como uid/gid 0.
- O processo encerrou repetidamente em cerca de 30 ms com `code=1 status=1`, reiniciando a cada cinco segundos.
- Teclas enviadas pelo TTL, inclusive `id`, ficaram apenas no console do kernel e nao foram consumidas por shell algum.
- Isso isola a falha no caminho do shell/script dinamico, antes de estabelecer os redirecionamentos para o char device; nao e falta de privilegio do servico no init.
- Proxima tentativa definida: usar o BusyBox ARM EABI5 estaticamente ligado da recovery original como interpretador e shell. Isso elimina linker/namespace/bibliotecas do Android e permite abrir o TTL em runtime sem a flag `console` do init.
- Ao recolocar o cartao no PC, o leitor apareceu inicialmente como `/dev/sdg` com modelo `STORAGE DEVICE`, mas capacidade `0 B`; nenhuma escrita foi feita nesse estado.

### 2026-07-26 - console via BusyBox estatico gravado na vendor

- Apos `udevadm settle`, o cartao foi reconhecido corretamente como `/dev/sdg`, 31.914.983.424 bytes (29,7 GiB), modelo `STORAGE DEVICE`.
- A particao raw `vendor` foi acessada apenas pelo offset 1.566.572.544 e limite 188.743.680 bytes; label `vendor`, UUID `bcd49384-72e5-4251-8473-e65db406d601`.
- O rc dinamico testado foi preservado em `work/card-debug-shell-20260726/vndservicemanager.rc.dynamic-probe-before-busybox`.
- Instalado `/vendor/bin/aquario-busybox` a partir do BusyBox da recovery original:
  - ELF32 ARM, little-endian, EABI5, estaticamente ligado;
  - uid root, gid 2000, modo 0755, label `u:object_r:vendor_shell_exec:s0`;
  - SHA256 `8ee056b12022a92b54fe6e5b57e13d5217ea8de949630717b4c54d4ed3eb5ea3`.
- Instalado `/vendor/bin/aquario-console-busybox`, que procura `/dev/ttyAML0`, `/dev/console` e `/dev/ttyS0`, e abre o primeiro char device encontrado com um shell BusyBox estatico:
  - modo 0755, label `u:object_r:vendor_shell_exec:s0`;
  - SHA256 `79aa0e35df4fa7b019ba3913b30780e4db18f4e711f118c8a45355e317a56c50`;
  - sintaxe validada com `sh -n`.
- `/vendor/etc/init/vndservicemanager.rc` agora executa diretamente `/vendor/bin/aquario-busybox sh /vendor/bin/aquario-console-busybox`, como root e `u:r:shell:s0`, sem depender do linker Android nem da flag prematura `console` do init.
  - SHA256 `7e7aa62217f6dfff47b4f40fec030bcefe7677a3d77f06a5c1cda2bd01af1d4d`.
- Vendor passou `e2fsck -fn`: 983/46080 arquivos, 39559/46080 blocos, sem erros.
- `/dev/sdg` foi liberado sem mounts nem loop devices. Proximo teste: recolocar no aparelho, bootar e pressionar Enter no TTL; o esperado e prompt root persistente em vez de reap com status 1.

### 2026-07-26 - teste BusyBox e boot v8 com console forcado no init

- Cartao recolocado no aparelho; U-Boot reconheceu SD `SC32G`, 29,7 GiB. Boot v7 e DTB foram carregados com sucesso por TFTP via `192.168.1.2`.
- Kernel 4.9.113 confirmou `32-bit EL0 Support`, montou `system` em `mmcblk1p18` e `vendor` em `mmcblk1p16`; HDMI selecionou 1280x720p60, embora continue com `ddc timeout`, diferencas de EDID e `monitor_timeout`.
- O BusyBox ARM32 estatico foi efetivamente executado como uid/gid 0 em `u:r:shell:s0`; audit confirmou entrypoint em `/vendor/bin/aquario-busybox`.
- Mesmo assim o processo encerrou com `status=1` em cerca de 10-15 ms e reiniciou a cada cinco segundos. A causa mais coerente e o `exec` com redirecionamento para o primeiro char device detectado: se a abertura falha, o builtin `exec` encerra o shell inteiro.
- Para testar sem nova escrita no cartao, `system/core/init/service.cpp` foi instrumentado especificamente quando `vndservicemanager` aponta para `/vendor/bin/aquario-busybox`:
  - forca `/dev/ttyAML0` como console e abre o device antes de reduzir credenciais/contexto;
  - registra sucesso/falha da abertura;
  - ignora o script intermediario e executa diretamente `aquario-busybox sh` com o stdio herdado do console.
- Novo `init` compilado no container correto `android9-aquario` com `m -j16 init`; build concluido com sucesso.
  - SHA256 do init: `74655e2f71eaa955b43bd703805297f21db645caf61f30126bd38202fa6de4ac`.
- Boot image v8 gerada preservando kernel e header do v7:
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-probe-v8-forced-console.img`;
  - SHA256 `897ef35c1392c0e1c9956767386fda956473a55dc79dda332c23b1e96ed79441`;
  - header validado: `ANDROID!`, kernel 8.489.803 bytes em `0x01080000`, ramdisk 4.839.047 bytes em `0x01000000`, pagina 2048;
  - gzip do ramdisk valido e strings de instrumentacao confirmadas no init embutido.
- Proximo teste: reiniciar manualmente para o U-Boot, carregar v8 mais o mesmo DTB e verificar `aquario opened service console '/dev/ttyAML0'`; depois pressionar Enter e executar `id`.

### 2026-07-26 - rc simplificado para shell BusyBox direto

- Usuario colocou o cartao no PC; confirmado novamente como `/dev/sdg`, 31.914.983.424 bytes, `STORAGE DEVICE`.
- O rc com BusyBox mais script foi preservado em `work/card-debug-shell-20260726/vndservicemanager.rc.busybox-script-before-direct`.
- `/vendor/etc/init/vndservicemanager.rc` foi simplificado para executar diretamente `/vendor/bin/aquario-busybox sh`:
  - `class core`, `console ttyAML0`, root, grupos root/shell/system/log/readproc e `seclabel u:r:shell:s0`;
  - nao existe mais script nem redirecionamento de stdio capaz de abortar o shell;
  - label `u:object_r:vendor_configs_file:s0`;
  - SHA256 `cb3248589b685cbbb0d47ce55704ac4bfa4127563091bf4257661292e7652a5d`.
- BusyBox no cartao permaneceu com SHA256 `8ee056b12022a92b54fe6e5b57e13d5217ea8de949630717b4c54d4ed3eb5ea3` e label `u:object_r:vendor_shell_exec:s0`.
- Vendor passou `e2fsck -fn` sem erros: 983/46080 arquivos, 39559/46080 blocos. Cartao liberado sem mount/loop.
- A v8 reconhece exatamente esse servico/binario, ignora a checagem prematura do console, abre `/dev/ttyAML0` no filho antes de reduzir atributos e executa diretamente o shell BusyBox.

### 2026-07-26 - v8 revelou nome real da UART; v9 ttyS0 pronta

- Boot v8 e DTB carregados por TFTP com sucesso; Android montou todas as particoes principais e chegou novamente a segunda fase.
- A instrumentacao funcionou e revelou o erro exato: `open('/dev/ttyAML0')` retorna `ENOENT` em todas as tentativas. O BusyBox direto encerrava por stdin em `/dev/null` apos o fallback.
- Revisao do log completo do kernel mostrou que este driver nao registra `ttyAML0`:
  - `c81004c0.serial: ttyS0 at MMIO 0xc81004c0 (irq = 20, base_baud = 1500000) is a meson_uart`;
  - `c11084c0.serial: ttyS1 ... is a meson_uart`.
- Portanto `earlycon=aml-uart,0xc81004c0` mantinha os logs visiveis, mas `console=ttyAML0` e todos os rc apontavam para um nome inexistente. Esse era o motivo de `Warning: unable to open an initial console` e das falhas do shell.
- `system/core/init/service.cpp` corrigido para abrir `/dev/ttyS0` no servico temporario e executar diretamente `aquario-busybox sh`.
- Novo init compilado no container `android9-aquario` com `m -j16 init`, SHA256 `21e35c8be68f8887ac1db406411ea55cdf765ea34a09fd0f4880df6d617bb887`.
- Gerada v9 com cmdline embutida tambem corrigida para `console=ttyS0,115200`:
  - TFTP `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-probe-v9-ttyS0.img`;
  - SHA256 `1537fbb17ec7e2766a4f0046db4593f46690994ac9db8f5a7a2ef7a5b3610a4e`;
  - ramdisk gzip validado e marcadores `forcing ttyS0`/`opened service console` confirmados no init.
- Proximo boot deve usar v9 e bootargs `console=ttyS0,115200`; esperado: `/dev/ttyS0` aberto pelo init e prompt BusyBox root persistente.

### 2026-07-26 - vendor do cartao corrigida de ttyAML0 para ttyS0

- Cartao confirmado no PC como `/dev/sdg`, 31.914.983.424 bytes.
- Rc anterior preservado em `work/card-debug-shell-20260726/vndservicemanager.rc.ttyAML0-before-ttyS0`.
- `/vendor/etc/init/vndservicemanager.rc` agora chama diretamente `/vendor/bin/aquario-busybox sh` com `console ttyS0`.
- O arquivo manteve label `u:object_r:vendor_configs_file:s0`, uid/gid root e modo 0644; SHA256 `8b3190b1d64775654d7ed6acce2084b7ef0af850e699af0e70fd3704fab9ce4b`.
- Vendor passou novamente `e2fsck -fn` sem erros (983/46080 arquivos, 39559/46080 blocos); cartao liberado sem mount ou loop.
- Proximo teste: cartao no aparelho, U-Boot, v9 via TFTP e bootargs com `console=ttyS0,115200`.

### 2026-07-26 - v9 abriu ttyS0; v10 corrige argv0 do BusyBox

- V9 bootada por TFTP com `console=ttyS0,115200`; o kernel passou a emitir a saida pela UART normal e earlycon, causando linhas duplicadas mas confirmando o console correto.
- O init abriu `/dev/ttyS0` com sucesso em todas as tentativas:
  - audit mostrou `read open` concedido em `serial_device`;
  - marcador `aquario opened service console '/dev/ttyS0'` apareceu;
  - portanto UART, device node, permissoes e stdio do servico estao resolvidos.
- O processo ainda encerrou por um detalhe do BusyBox multicall: executado com `argv[0]="/vendor/bin/aquario-busybox"`, ele tentou localizar um applet chamado `aquario-busybox` e imprimiu `aquario-busybox: applet not found`.
- O init foi corrigido para usar `execl(path, "busybox", "sh", nullptr)`, mantendo o ELF no mesmo path mas fornecendo o nome multicall correto em `argv[0]`.
- Novo init compilado no container `android9-aquario` com `m -j16 init`, SHA256 `c981e0b69bda3a48bb5a0165267ae6410bc881fc38317825c54d561662770521`.
- V10 pronta no TFTP:
  - `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-compat-minlibs-probe-v10-busybox-argv0.img`;
  - SHA256 `d2a09b9d7fe493d4c3d5942dc2a32a04e43f754d2fe55915d051581eb5755cb4`;
  - ramdisk gzip validado.
- Proximo boot v10 deve finalmente manter o shell BusyBox root no `ttyS0`.

### 2026-07-26 - BusyBox instalado com nome multicall canonico

- Cartao novamente no PC e confirmado como `/dev/sdg`, 31.914.983.424 bytes.
- Em vez de depender do override de `argv[0]`, foi instalada uma copia identica em `/vendor/bin/busybox`, nome que o multicall reconhece nativamente:
  - SHA256 `8ee056b12022a92b54fe6e5b57e13d5217ea8de949630717b4c54d4ed3eb5ea3`;
  - uid root, gid 2000, modo 0755, label `u:object_r:vendor_shell_exec:s0`.
- Rc anterior preservado em `work/card-debug-shell-20260726/vndservicemanager.rc.aquario-busybox-before-canonical`.
- `/vendor/etc/init/vndservicemanager.rc` agora executa `/vendor/bin/busybox sh` com `console ttyS0`, root e `u:r:shell:s0`:
  - SHA256 `5b2fd4f7acd15bf6bd14dd730c00b2d9575ccd4bcc059a09da6f9af05f6f297a`;
  - label `u:object_r:vendor_configs_file:s0`.
- Essa forma funciona com a semantica normal do BusyBox: basename `busybox`, primeiro argumento `sh`. Como o path nao e mais `aquario-busybox`, o override especial da v10 nao entra e o init usa normalmente a flag `console ttyS0`, cuja abertura ja foi comprovada pela v9.
- Vendor passou `e2fsck -fn` sem erros: 984/46080 arquivos, 39771/46080 blocos; cartao liberado sem mount/loop.

### 2026-07-26 - shell root funcional, bibliotecas e system minima diagnosticadas

- Boot v10 com vendor canonica `/vendor/bin/busybox sh` abriu shell root persistente em `ttyS0`; prompt `~ #`/`AQUARIO#` confirmado.
- Identidade do shell: `uid=0(root) gid=0(root) groups=1000(system),1007(log),2000(shell),3009`; subprocessos BusyBox aparecem em `u:r:vendor_shell:s0`. SELinux continua permissive.
- Devices confirmados:
  - `/dev/binder` 10:63, `/dev/hwbinder` 10:62, `/dev/vndbinder` 10:61, todos 0666;
  - `/dev/ttyS0` 241:0, root:root 0600.
- Binarios dinamicos Android inicialmente falhavam com `library "libselinux.so" not found`. Busca no aparelho confirmou que `libselinux.so` nao existia em `/system` nem `/vendor`.
- Dependencias do ELF original `/vendor/bin/vndservicemanager.real`:
  - `liblog.so`, `libcutils.so`, `libselinux.so`, `libc++.so`, `libc.so`, `libm.so`, `libdl.so`.
- `libselinux.so` do build stv3000 requer adicionalmente `libcrypto.so`, `libpcre2.so` e `libpackagelistparser.so`; as demais dependencias ja estavam na arvore minima.
- Ethernet ativada pelo shell:
  - `eth0` recebeu MAC `66:ad:0c:31:aa:04`, link 100 Mbps/full e IP `192.168.1.139/24`;
  - ping para gateway/TFTP `192.168.1.2` passou sem perdas.
- Raiz `/dev/block/system` remontada rw e quatro bibliotecas ARM32 transferidas por TFTP para `/system/lib`:
  - `libselinux.so` 80.960 bytes;
  - `libcrypto.so` 840.660 bytes;
  - `libpcre2.so` 102.816 bytes;
  - `libpackagelistparser.so` 20.588 bytes.
- Depois disso, `/vendor/bin/vndservicemanager.real /dev/vndbinder` permaneceu vivo e assumiu o context manager binder; relancado em background como PID 2665. Portanto o ELF e o binder estao funcionais e a causa do loop era o conjunto de bibliotecas ausente.
- Bloqueio seguinte confirmado: a system atualmente montada no aparelho tem apenas dois arquivos em `/system/bin`: `linker` e `mke2fs`. Nao existem em nenhum path `servicemanager`, `hwservicemanager`, `surfaceflinger`, `app_process32` ou framework executavel suficiente para UI.
- Mount runtime: `/dev/block/system` em `/` como ext4; portanto a ausencia e da particao system atual, nao um bind mount da vendor.
- Imagens completas verificadas offline:
  - `work/system-inittrace-20260726/system-before-inittrace-from-card.raw.img`, 1.048.576.000 bytes, 841 MB usados;
  - `work/aidan-systemroot-patched-v4-no-system-vendor-omx-20260722/system-aidan-systemroot-patched-v4-no-system-vendor-omx.raw.img`, mesmo tamanho/conteudo-base.
- A readback preservada do proprio cartao tem 158 arquivos em `/system/bin`, incluindo:
  - `app_process32`, `servicemanager`, `hwservicemanager`, `surfaceflinger`, `adbd`, `audioserver` e toybox;
  - ocupa cerca de 841 MB e cabe exatamente na regiao system de 1.000 MiB iniciada no offset 2150 MiB.
- Proxima acao correta: cartao no PC, gravar `system-before-inittrace-from-card.raw.img` no offset 2150 MiB com `conv=fsync,notrunc`, verificar readback/hash e filesystem. Preservar vendor atual, bootloader e demais regioes. Depois boot v10/DTB e observar Android core/graphics.

### 2026-07-26 - system Android 9 completa restaurada no cartao

- Ate esta etapa foram compilados do source principalmente o kernel 4.9 e o `init` Android 9. A arvore AOSP 9 completa existe em `infra/aidan/aosp9`, mas o `system.img` atual expande para aproximadamente 1,946 GB e nao cabe diretamente na regiao system de 1.000 MiB do layout atual.
- Para chegar ao primeiro boot grafico pelo caminho mais curto, foi criada uma copia independente da system completa preservada:
  - origem: `work/system-inittrace-20260726/system-before-inittrace-from-card.raw.img`;
  - trabalho: `work/system-full-v10-20260726/system-full-v10.raw.img`;
  - tamanho exato: 1.048.576.000 bytes;
  - SHA256 final: `471122d7cf0eff505a58c6e9abc04949a580308c3f24f5e3219264cdd2be732a`.
- A system de trabalho contem 158 arquivos em `/system/bin`, incluindo `app_process32`, `hwservicemanager`, `servicemanager`, `surfaceflinger`, `adbd` e `audioserver`. Tambem contem `libselinux.so`, `libcrypto.so`, `libpcre2.so`, `libpackagelistparser.so` e `libext2fs.so` em `/system/lib`.
- O `/init` da imagem foi substituido pelo `init` ARM32 recem-compilado em `infra/aidan/aosp9/out/target/product/stv3000/root/init`, SHA256 `c981e0b69bda3a48bb5a0165267ae6410bc881fc38317825c54d561662770521`, root:root 0755. O init anterior foi preservado dentro da imagem como `/init.pre-custom-v10`.
- Vendor no cartao foi corrigida antes da gravacao da system:
  - `/vendor/bin/vndservicemanager` voltou a ser o ELF original, igual a `vndservicemanager.real`, SHA256 `88979dafa78d824171fb9da92a1cfe17abb89d61d7917c3d2055d7ddeee18563`;
  - uid root, gid 2000, modo 0755 e label `u:object_r:vndservicemanager_exec:s0`;
  - `/vendor/etc/init/vndservicemanager.rc` volta a iniciar o servico real em `/dev/vndbinder` e tambem define `aquario_console` como `/vendor/bin/busybox sh`, root, `console ttyS0`, `u:r:shell:s0`;
  - rc final SHA256 `6574e89ea00aec30ccc00d32f5aa965d223c382232edee299e279c3ad8fc7737`, label `u:object_r:vendor_configs_file:s0`.
- A system foi gravada em `/dev/sdg` no offset 2150 MiB (`2254438400` bytes), exatamente 1000 MiB, usando `dd ... bs=1M seek=2150 count=1000 conv=fsync,notrunc`.
- O SHA256 da leitura integral diretamente do cartao foi `471122d7cf0eff505a58c6e9abc04949a580308c3f24f5e3219264cdd2be732a`, identico ao arquivo de trabalho.
- `e2fsck -fn` passou sem erros tanto na vendor quanto na system gravada. Verificacao final diretamente do cartao confirmou os 158 binarios e o init novo. Nenhum mount ou loop de `/dev/sdg` ficou ativo; cartao pronto para voltar ao aparelho.
- Proximo teste: bootar pelo U-Boot com o boot v10 e `gxl_p281_1g_khadas_fstab_systemroot.dtb`; no TTL observar `vndservicemanager`, `servicemanager`, `hwservicemanager`, `zygote`, `surfaceflinger` e erros de HAL/graphics. O v10 ainda contem `keep_bootcon`, portanto pode duplicar linhas no serial, mas isso nao impede o boot.

### 2026-07-26 - boot da system completa revelou arvore `/system` oculta

- Boot v10 iniciado por TFTP no U-Boot com:
  - `ipaddr=192.168.1.139`, `serverip=192.168.1.2`, `gatewayip=192.168.1.2`;
  - `boot-khadas-fresh-p281-compat-minlibs-probe-v10-busybox-argv0.img`, 13.332.480 bytes, em `0x1080000`;
  - `gxl_p281_1g_khadas_fstab_systemroot.dtb`, 56.953 bytes, em `0x1000000`;
  - `setenv bootargs; bootm 0x1080000`.
- `saveenv` nao funciona neste hardware sem eMMC: U-Boot retorna timeout/MMC init failed. As variaveis permanecem validas somente na sessao atual.
- Kernel 4.9.113 subiu, detectou EDID e selecionou inicialmente 1080p60. Android montou `/dev/block/system` em `/`, iniciou segundo estagio e abriu shell root no `ttyS0`.
- Apesar da system completa estar gravada, a arvore visivel em `/system` tinha apenas diretorios vazios. Por isso `libselinux.so`, `setprop`, `servicemanager`, `hwservicemanager` e `surfaceflinger` nao eram encontrados e `vndservicemanager` encerrava com status 1.
- O mapa real do kernel confirmou que nao era erro de offset:
  - system `mmcblk1p18`, offset `0x86600000` = 2150 MiB, tamanho `0x74000000`;
  - o `/init` runtime tinha o SHA correto da v10: `c981e0b69bda3a48bb5a0165267ae6410bc881fc38317825c54d561662770521`.
- Montar novamente `/dev/block/system` em `/mnt/testsystem` mostrou os 158 binarios esperados em `/mnt/testsystem/system/bin`. Portanto os dados estavam corretos no cartao; uma arvore vazia do primeiro estagio estava ocultando o subdiretorio `/system` durante o segundo estagio.
- Teste ao vivo comprovou a solucao:
  - `mount --bind /mnt/testsystem/system /system` tornou imediatamente visiveis todas as bibliotecas e executaveis;
  - apos `ctl.stop`/`ctl.start`, `/vendor/bin/vndservicemanager /dev/vndbinder` permaneceu ativo;
  - `servicemanager`, `hwservicemanager` e `surfaceflinger` ainda nao podiam ser iniciados por `ctl.start`, pois seus rc nao tinham sido parseados quando `/system/etc/init` estava oculto;
  - zygote estava definido pelo rc raiz, mas abortou por ausencia dos service managers. Isso confirma que o bind deve ocorrer antes de `LoadBootScripts()`.

### 2026-07-26 - init v11 corrige exposicao da system antes do parser

- Alterado `infra/aidan/aosp9/system/core/init/init.cpp`:
  - nova funcao `ExposeAquarioSystemTree()` roda no inicio do segundo estagio;
  - se `/system/bin/servicemanager` estiver ausente, monta `/dev/block/system` read-only em `/mnt/aquario_system`;
  - faz bind recursivo de `/mnt/aquario_system/system` sobre `/system`;
  - executa antes de `LoadBootScripts()`, permitindo parse de `/system/etc/init` e definicao dos servicos centrais.
- Build correta no container:
  - container `android9-aquario`;
  - lunch `aquario_stv3000-userdebug`;
  - `m -j16 init` concluido com sucesso em 7 segundos.
- Novo init ARM32:
  - `infra/aidan/aosp9/out/target/product/stv3000/root/init`;
  - 1.508.224 bytes;
  - SHA256 `55c21ff3d9c69b73e13e631ccd23dbe2be2b8bc2bd204857f456f0873c535dae`.
- Cartao `/dev/sdg` montado pelo offset system de 2150 MiB; init v10 preservado em `work/system-bind-fix-v11-20260726/init.v10.before-bind-fix`.
- Novo init instalado como `/init`, root:root 0755. `strings` confirmou os marcadores `aquario: failed to mount system staging tree` e `aquario: exposed nested system tree before parsing boot scripts`.
- `e2fsck -fn` da system passou sem erros: 2419/64000 arquivos, 219957/256000 blocos. Nenhum mount ou loop de `/dev/sdg` ficou ativo.
- Proximo boot deve reutilizar boot v10 + mesmo DTB. Confirmar primeiro o marcador `aquario: exposed nested system tree`, depois starts de `servicemanager`, `hwservicemanager`, `surfaceflinger`, zygote e system_server. Em seguida diagnosticar HAL graphics/HDMI restante.

### 2026-07-27 - v11 precisava estar tambem no ramdisk TFTP

- Primeiro teste apos instalar o init v11 apenas na particao system ainda bootou o init v10 do ramdisk:
  - SHA256 runtime de `/init`: `c981e0b69bda3a48bb5a0165267ae6410bc881fc38317825c54d561662770521`;
  - SHA256 do novo init ja presente na system: `55c21ff3d9c69b73e13e631ccd23dbe2be2b8bc2bd204857f456f0873c535dae`.
- Isso explica por que o marcador novo nao apareceu e `/system` continuou oculto. Neste fluxo de boot, a segunda fase observada ainda usa a copia de init contida no ramdisk TFTP/rootfs; atualizar somente `/init` na system nao altera o executavel runtime.
- Gerado boot v11 preservando kernel, cmdline, enderecos e demais arquivos do ramdisk v10, substituindo somente `/init`:
  - work: `work/teste-khadas-fresh-20260726-system-bind-v11/bootimgs/boot-khadas-fresh-p281-system-bind-v11.img`;
  - TFTP: `/home/fabiano/opw/openwrt/bin/targets/qualcommax/ipq50xx/boot-khadas-fresh-p281-system-bind-v11.img`;
  - tamanho 13.334.528 bytes;
  - SHA256 `81c05d67cdac1be51f052cdbfe734129d8fc5ed135b3c6ca667fd117c736ac6b`;
  - kernel 8.489.803 bytes em `0x01080000`, ramdisk 4.839.612 bytes em `0x01000000`, pagina 2048;
  - cmdline mantida com `console=ttyS0`, `earlycon`, `keep_bootcon`, permissive e `maxcpus=4`.
- Ramdisk foi extraido novamente para verificacao; `/init` embutido tem SHA256 `55c21ff3d9c69b73e13e631ccd23dbe2be2b8bc2bd204857f456f0873c535dae` e contem `aquario: exposed nested system tree before parsing boot scripts`.
- Cartao voltou ao PC como `/dev/sdg`, 31.914.983.424 bytes. Nenhuma escrita adicional e necessaria nesta rodada; system ja tem o mesmo init v11 e o boot corrigido sera carregado por TFTP.
- Proximo teste: cartao no aparelho, U-Boot, carregar `boot-khadas-fresh-p281-system-bind-v11.img` em `0x1080000`, o mesmo DTB em `0x1000000`, limpar `bootargs` e `bootm 0x1080000`.

### 2026-07-27 - primeiro boot efetivo do Android com init v11

- O boot v11 por TFTP confirmou no serial o marcador `aquario: exposed nested system tree before parsing boot scripts`. A correcao de bind da arvore aninhada funciona e os arquivos de `/system/etc/init` passam a ser analisados.
- O Android avancou ate iniciar os servicos centrais e varios HALs. Foram observados starts de `hwservicemanager`, `audioserver` e `surfaceflinger`; portanto o bloqueio anterior de system oculta foi removido.
- O caminho grafico ainda nao permanece ativo:
  - `vendor.gralloc-2-0` (`/vendor/bin/hw/android.hardware.graphics.allocator@2.0-service`) encerra repetidamente com exit status 1;
  - `surfaceflinger` e `hwservicemanager` voltam a ser iniciados em ciclos de aproximadamente 5 segundos, indicando crash/restart;
  - `hidl_memory` e `thermalservice` encerraram com SIGABRT/status 6;
  - `vendor.gatekeeper-1-0` e `vendor.keymaster-3-0` tambem encerraram com status 1.
- O kernel/HDMI detecta a conexao e configura inicialmente 1080p60, mas ainda nao aparece composicao Android no display. O bloqueio imediato mais provavel e o conjunto `hwservicemanager` + allocator/gralloc + `surfaceflinger`, nao o driver HDMI basico.
- O log completo desta rodada esta preservado em `tools/recovery-lab/logs/serial_ttyUSB1.log`, especialmente proximo das linhas 450453-450640. Tombstones em `/data/tombstones` ainda precisam ser coletados numa inicializacao estavel para obter a mensagem exata dos aborts.
- Duas inicializacoes terminaram com `reboot: Restarting system with command 'bootloader'` perto de 29-30 segundos. A origem ainda nao foi provada: a forma da mensagem nao inclui `(init)` e pode ser comando direto/entrada serial pendente; nao assumir ainda que seja politica de reboot do Android.
- Na tentativa seguinte o kernel encontrou erros persistentes de SD durante o primeiro estagio: CRC/timeout em `meson-mmc`, comando 51, alternando `rx_phase` ate esgotar retries. Essa partida ficou presa antes de montar as particoes e nao abriu shell. O cartao, contato/leitor ou timing MMC deve ser verificado ao retomar.
- Estimativa tecnica na pausa: o sistema ja chega ao Android core, mas faltam diagnosticar e corrigir os crashes HIDL/graphics antes de haver imagem HDMI. A expectativa e de uma ou poucas correcoes focadas se os tombstones apontarem incompatibilidade de biblioteca/configuracao; nao ha prazo confiavel sem esses registros.
- Os testes fisicos foram pausados porque o adaptador TTL do usuario queimou. Retomar somente com novo acesso serial; primeiro obter boot estavel, coletar `logcat -b all` e os tombstones antes do reboot, e entao corrigir vendor/system ou rebuildar os componentes afetados.

### 2026-07-27 - novo adaptador TTL ainda sem recepcao eletrica

- Novo adaptador identificado como CH341 (`1a86:5523`) em `/dev/ttyUSB0`.
- `conectar_ttl.sh` criou corretamente o container `serial_ttyUSB0` e o broker escuta em `127.0.0.1:31337`.
- Configuracao calibrada mantida: U-Boot em 117200 baud e troca automatica do kernel para 111600 baud; `tx-byte-delay=0.002`.
- O `.env` ainda apontava para o adaptador antigo ausente `/dev/ttyACM1`; corrigido para `/dev/ttyUSB0`.
- Um Enter foi transmitido pelo broker, mas `logs/serial_ttyUSB0.log` permaneceu exatamente com 44.854.417 bytes e nenhum cliente recebeu resposta. Logo o problema atual nao e `nc`, porta TCP ou container: nenhum byte eletrico chega ao RX do CH341.
- Antes de retomar o Android, testar loopback do adaptador novo (TTL desconectado da box, unir TX e RX e verificar eco). Se passar, conferir GND comum, cruzamento TX da box -> RX do adaptador e RX da box -> TX do adaptador, sem ligar VCC, em nivel TTL 3,3 V.
- Loopback posteriormente testado tambem de forma automatizada em 115200 baud: enviado `LOOPBACK-7f3a`, recebidos exatamente 0 bytes. O driver aceitou a transmissao sem erro.
- Ao reconectar, o adaptador mudou de `/dev/ttyUSB0` para `/dev/ttyUSB1`; link persistente: `/dev/serial/by-id/usb-1a86_USB_UART-LPT-if00-port0`.
- `udevadm` confirma driver Linux `ch341`, USB `1a86:5523`, modelo `USB UART-LPT`; `dmesg` mostra attach normal, sem erro do dispositivo. Se TX/RX estavam realmente unidos, os pinos escolhidos nao sao o canal UART/modo correto desse modulo ou o adaptador esta defeituoso.
- Correcao posterior do usuario: o aparelho e o novo TTL devem operar em 115200 baud; a interpretacao de falha fisica/loopback nao estava confirmada. As taxas herdadas 117200/111600 eram configuracao antiga e causavam tela vazia. `.env` corrigido para 115200 tanto no bootloader quanto no kernel.

### 2026-07-27 - TTL recuperado, reboot critico suprimido e Binder corrigido no v14

- O CH341 voltou a funcionar em `/dev/ttyUSB0`, usando o link persistente `/dev/serial/by-id/usb-1a86_USB_UART-LPT-if00-port0` e 115200 baud no U-Boot e kernel. O container serial anterior havia ficado preso ao node antigo `/dev/ttyUSB1`; reiniciar `conectar_ttl.sh` recriou `serial_ttyUSB0` corretamente.
- O reboot perto de 29 segundos foi provado como politica do init: `servicemanager` encerrava quatro vezes e o processo critico disparava reboot para bootloader. Em `system/core/init/service.cpp`, o `LOG(FATAL)` dessa politica foi trocado por `LOG(ERROR)` durante o bring-up, preservando o aparelho ligado para coleta.
- Init v12 com reboot critico suprimido: SHA256 `67e2580203d82c4acbcc3892c10a5e1de2362c814c280c31bd1cafa9e7fc3737`.
- O primeiro teste Binder32 (v13/kernel #9) estava errado para o Android core: seus binarios ARM32 foram compilados com estruturas Binder de protocolo 8. O define `-DBINDER_IPC_32BIT` fazia o kernel anunciar protocolo 7.
- A causa principal do `ENOTTY` anterior era outra: customizacao antiga em `system/core/init/init.cpp` criava nodes fixos `/dev/binder=10:63`, `/dev/hwbinder=10:62`, `/dev/vndbinder=10:61`, mas o kernel 4.9 registra respectivamente minors `61`, `60`, `59`. Assim `/dev/binder` apontava para `rfkill`, e nao para Binder.
- `init.cpp` foi corrigido para criar `10:61`, `10:60`, `10:59`; o define Binder32 foi removido de `work/khadas-linux-pie-fresh-20260721/drivers/android/Makefile`.
- Rebuild no container correto `android9-aquario`, lunch `aquario_stv3000-userdebug`, `m -j16 init` e kernel AArch64 4.9 com `-j16`:
  - init: 1.508.172 bytes, SHA256 `92ebe8ce0943c490290799e37af6a49300c591a9f83bbadf3d3ae780eb3a2ffd`;
  - kernel #10 `Image.gz`: 8.490.057 bytes, SHA256 `f1d82fab167313d6259f24f1655e56602d57f47735e27bbff885a6ac0e889e87`.
- Boot v14: `work/teste-khadas-fresh-20260727-binder-nodes-v14-1828/bootimgs/boot-khadas-fresh-p281-binder-nodes-v14.img`, 13.332.480 bytes, SHA256 `3b9b8e78814e76cb05df32e244ea2b616c34949bae2c2ed7dfd7645312a7ddbb`; copia TFTP com mesmo nome/hash.
- TFTP pela ether8/VRF precisou aguardar o PHY negociar 100 Mbps/full. O `invade` confirmou ether8 `link-ok` e rota ativa `192.168.1.0/24` na tabela `mr80x-recovery`; depois o v14 transferiu a 3,1 MiB/s.
- Resultado v14 confirmado no aparelho:
  - `/proc/misc`: binder 61, hwbinder 60, vndbinder 59;
  - nodes `/dev` exatamente iguais;
  - `servicemanager`, `hwservicemanager` e `vndservicemanager` permanecem vivos e propriedades `running`.

### 2026-07-27 - bloqueios restantes isolados: vendor Binder7 e Mali ausente

- Alguns HALs proprietarios da vendor usam `libbinder.so` protocolo 7 e abortam contra o driver protocolo 8: `Binder driver protocol(8) does not match user space protocol(7)`. A `libbinder.so` da system usa protocolo 8 e mantem o Android core funcional.
- O allocator graphics chegou a registrar, mas o SurfaceFlinger falha em seguida:
  - `libGLES_mali.so` carrega;
  - `eglInitialize` retorna `EGL_BAD_ALLOC`;
  - SurfaceFlinger recebe SIGSEGV em `GLExtensions::initWithEGLStrings`, pois `/dev/mali` nao existe.
- O `mali.ko` no cartao era ARMv7, vermagic `4.9.y ... ARMv7`, e o kernel atual e AArch64. `insmod` retornava `invalid module format`. A copia AArch64 antiga da arvore AOSP tinha vermagic 3.14.29 e tambem nao serve.
- Fonte oficial baixado do GitHub: `https://github.com/khadas/android_vendor_amlogic_gpu.git`, branch `khadas-vims-pie`, em `work/mali-khadas-vims-pie`.
- Mali Utgard r6p1 compilado no container `android9-aquario` contra o mesmo kernel output #10, AArch64, `-j16`:
  - `work/build-mali-r6p1-khadas-4.9-20260727-1835/mali.ko`;
  - 569.904 bytes, ELF AArch64;
  - vermagic `4.9.y SMP preempt mod_unload modversions aarch64`;
  - SHA256 `00ec929c1d8e8b79fadf58be6f3aa123587653521cda3c1670e01134202e9ed5`.
- Cartao `/dev/sdg` corrigido diretamente:
  - vendor no offset 1.566.572.544, system no offset 2.254.438.400;
  - `/vendor/lib/modules/mali.ko` substituido pelo r6p1 AArch64 4.9 acima;
  - `/vendor/lib/libbinder.so` substituida byte a byte pela `/system/system/lib/libbinder.so` protocolo 8, SHA256 `184f163c33eb62b825a4fbf8d32262bca72f7e4852595fa74a6da4490d2effd4`;
  - backups em `work/card-v14-fix-20260727-1840/backup/`;
  - modos/inodes preservados; `mali.ko` manteve label `u:object_r:vendor_file:s0`;
  - `e2fsck -fn` passou sem erros em vendor e system; loops desmontados e removidos.
- Proximo teste: recolocar o cartao, bootar v14 por TFTP, confirmar no inicio `Mali device driver loaded` e `/dev/mali`; depois verificar se `eglInitialize`, SurfaceFlinger, zygote e system_server permanecem vivos. Conferir tambem se os HALs antes presos em Binder7 passam a registrar com a nova lib da vendor.

### 2026-07-27 - Mali/HWC funcionais e boot v15 automatiza servicos vendor

- Cartao corrigido recolocado no aparelho e boot v14 carregado por TFTP, com `ipaddr=192.168.1.139`, `serverip=192.168.1.2`, DTB `gxl_p281_1g_khadas_fstab_systemroot.dtb` e `bootargs` limpo.
- O SD teve timeouts iniciais em CMD18/CMD13, percorreu as fases de RX e se recuperou. As particoes foram montadas e o Android chegou ao shell.
- A correcao Mali foi confirmada integralmente:
  - `mali.ko` AArch64 carregado, 286720 bytes residentes;
  - kernel registrou `Mali: Mali device driver loaded`;
  - `/dev/mali` criado como `10:49`, modo 0666, grupo graphics;
  - SurfaceFlinger carregou `/vendor/lib/egl/libGLES_mali.so` sem `EGL_BAD_ALLOC`;
  - EGL 1.4 inicializou e OpenGL ES identificou `ARM Mali-450 MP`, ES 2.0, textura maxima 4096.
- A troca da libbinder vendor eliminou dos logs coletados os aborts `Binder driver protocol(8) does not match user space protocol(7)`. Os tres service managers permaneceram ativos.
- O bloqueio grafico seguinte foi isolado: SurfaceFlinger esperava `android.hardware.graphics.composer@2.1::IComposer/default`, pois os RC da vendor nao estavam disponiveis no momento do parser inicial.
- O ramdisk ainda definia `system_control /system/bin/systemcontrol`, caminho inexistente; o binario real esta em `/vendor/bin/systemcontrol`. O comando `start system_control` confirmou o erro de `stat` no caminho antigo.
- Teste manual provou toda a cadeia:
  - `/vendor/bin/hw/android.hardware.graphics.composer@2.2-service.real` ficou vivo e aguardou systemcontrol;
  - ao iniciar `/vendor/bin/systemcontrol`, foram registrados `ISystemControl` 1.0/1.1 e `IComposer` 2.1/2.2;
  - SurfaceFlinger passou a compor, OSD0 foi habilitado e HDMI mudou para `2160p30hz` com HPD 1;
  - `system_server` e `/system/bin/bootanimation` ficaram ativos.
- O `imageserver` do rc raiz entrava em loop a cada 5 segundos porque `seclabel u:r:imageserver:s0` nao existe na policy carregada. Foi desativado temporariamente para o bring-up.
- Gerado boot v15 com apenas ajustes no `init.amlogic.rc` do ramdisk:
  - `system_control` agora aponta para `/vendor/bin/systemcontrol`, com grupos `system root media audio`;
  - adicionado `vendor.hwcomposer-2-2` apontando diretamente ao binario `.real`;
  - `imageserver` marcado `disabled`;
  - work: `work/teste-khadas-fresh-20260727-vendor-services-v15-1945/`;
  - ramdisk: 4.839.289 bytes, SHA256 `c5233ac76f2896c352da2a16fc75e3d96fb23237dc46581362abd6ce6222bfb2`;
  - boot: `boot-khadas-fresh-p281-vendor-services-v15.img`, 13.332.480 bytes, SHA256 `6c5c348002cf7ddab6ad94dd921caf29318b9e3c4d6289af9832b38ad21f9df9`;
  - copia TFTP em `openwrt/bin/targets/qualcommax/ipq50xx/` com hash identico.
- O v15 foi reextraido e validado: kernel #10 mantido; `/init` SHA256 `92ebe8ce0943c490290799e37af6a49300c591a9f83bbadf3d3ae780eb3a2ffd`; novos blocos de servico presentes no CPIO.
- Pendencias observadas no boot manual: `sys.boot_completed` ainda vazio, bootanimation ativo e spam `failed to dup EGL native fence sync: 0x3000`. Primeiro testar o v15 automatico; depois coletar ActivityManager/SystemServer sem o ruido do composer ausente.

### 2026-07-27 - teste v15 e correcao de dominio no v16

- O v15 foi carregado por TFTP e chegou novamente ao Android. Mali, `/dev/mali`, zygote, system_server, SurfaceFlinger e o processo composer iniciaram automaticamente.
- O composer ficou em `restarting` e o display permaneceu `invalid` porque `system_control` nao conseguia executar.
- Causa exata confirmada no log do init: `cannot setexeccon('u:r:system_control:s0') for system_control: Invalid argument`, seguido de reap com status 6. A policy Aidan carregada nao possui esse dominio Amlogic.
- Gerado v16 alterando temporariamente apenas o seclabel de `system_control` para o dominio valido `u:r:shell:s0`, o mesmo contexto no qual o teste manual havia registrado SystemControl 1.0/1.1 com sucesso:
  - work: `work/teste-khadas-fresh-20260727-systemcontrol-shell-v16-2010/`;
  - ramdisk: 4.839.284 bytes, SHA256 `3cc0dcb356feba87497d3dd0950b8ab7644f8399ed6cbbcf49f9edeb34b5998b`;
  - boot: `boot-khadas-fresh-p281-systemcontrol-shell-v16.img`, 13.332.480 bytes, SHA256 `25189903a4fa749a4691dfa6929661dda5d575324696ebc1ab141a18495c6cd4`;
  - copia TFTP com hash identico.
- Esta troca de dominio e somente para bring-up permissivo. A solucao final deve integrar os tipos/regras `system_control` e `system_control_exec` na policy compilada.

### 2026-07-27 - boot completo manual no v16 e automatizacao dos HALs v17-v19

- No v16, `system_control`, composer 2.1/2.2, SurfaceFlinger, zygote e system_server ficaram ativos; Mali permaneceu funcional e o HDMI foi configurado em `2160p30hz`, HPD 1.
- O system_server aguardava HALs existentes na vendor mas ausentes da configuracao init: memtrack, power, light, health, camera provider, thermal, USB, TV CEC e Wi-Fi. Todos foram iniciados manualmente e registraram suas interfaces HIDL.
- O ultimo bloqueio fatal foi `WifiStateMachine` com `NoSuchElementException` em `IWifi.getService`. Depois de iniciar manualmente `/vendor/bin/hw/android.hardware.wifi@1.0-service`, o sistema confirmou `sys.boot_completed=1`, `init.svc.bootanim=stopped` e `service.bootanim.exit=1`.
- V17 adicionou os HALs ao `init.amlogic.rc`, mas forcou todos ao dominio `u:r:shell:s0`. Isso foi incorreto para os HALs padrao: o Wi-Fi falhou continuamente com `cannot execve(...wifi@1.0-service): Operation not permitted`.
- V18 removeu o `seclabel` explicito dos HALs padrao, mantendo shell apenas em `system_control` e `hdmicecd`. Ramdisk SHA256 `687547e6d6c3de3d862c99ce72945a7060c3e7c78e7dc86794f9ef2fe0a2be80`; boot SHA256 `ee8f997b3ee2da2088e26c9a15f074fd1cf363b69c1835c9b718a4781822fae3`.
- Teste v18 por TFTP em `192.168.1.2`: memtrack e os demais HALs padrao entraram em seus dominios esperados, mas o Wi-Fi continuou recusado pelo init. `ls -lZ` confirmou o executavel como `u:object_r:hal_wifi_default_exec:s0`, SELinux permissivo e servico em `restarting`. A execucao manual no shell ja havia funcionado, portanto o problema e a transicao init/policy especifica do Wi-Fi, nao o kernel nem o arquivo binario.
- O `onrestart restart surfaceflinger` do servico Wi-Fi fazia cada tentativa matar SurfaceFlinger e, por consequencia, reiniciar zygote/system_server. Isso foi removido no v19.
- Estrategia v19: iniciar `/system/bin/sh /init.aquario.wifi.sh` explicitamente em `u:r:shell:s0`; o wrapper executa o HAL do Wi-Fi como no teste manual comprovado. Esta ainda e uma solucao de bring-up permissivo; a imagem final deve recompilar a policy com a transicao/domino correto do Wi-Fi.
- V19 gerada em `work/teste-khadas-fresh-20260727-wifi-wrapper-v19`: ramdisk 4.841.628 bytes, SHA256 `ad45ddef6d80fde53a21938fa0bfa7a775d4b31bce6055dea278dca5fe0a3a83`; boot 13.336.576 bytes, SHA256 `2b332b5df6df9eb39c08a4fa95e2432706354af39b346181e710ac1b6b3a8ec8`. A copia TFTP tem hash identico e o CPIO reextraido confirmou wrapper 0755/root:root.
- O primeiro teste v19 foi invalido para Android: o kernel falhou em CMD51 durante todas as fases de recepcao do SD, depois falhou CMD1 e reiniciou sem montar particoes. O cartao foi levado ao PC como `/dev/sdg`.
- Layout Amlogic confirmado no cartao: `boot` offset 1.438.646.272, tamanho 16.777.216; setor inicial `0x2ae000`, contagem `0x8000` setores de 512 bytes. Backup da regiao anterior em `work/card-v19-20260727/boot-before-v19.img`, SHA256 `be4603cba6b786c8cb2b00aa1774f956671212566a1d39b32e1a076c89bf5a58`.
- A regiao boot do cartao foi zerada e recebeu a v19 diretamente. Readback de 16 MiB em `work/card-v19-20260727/boot-readback-v19-partition.img`; os primeiros 13.336.576 bytes conferem byte a byte e SHA256 com a v19, e todo o restante esta zerado.
- `e2fsck -fn` somente leitura passou sem erros em vendor (offset 1.566.572.544, 512 MiB) e system (offset 2.254.438.400, 1.812,5 MiB). Logo o boot perdido nao foi corrupcao logica dessas particoes.
- O DTB comprovado configurava o slot SD e seu subno com frequencia maxima de 100 MHz. Foi criada variante conservadora TFTP `gxl_p281_1g_khadas_fstab_systemroot_sd25m.dtb`, limitada a 25 MHz em ambos os campos, 56.953 bytes, SHA256 `c90881d00f5a2852702eece472a3c8c44d4661ee2a29fbf17243c26caa9a2e65`. O original foi preservado, SHA256 `495b03530ef908ce833b2e72d56d7205d012c0ecc52630485b1e38fb3872b517`.
- Proximo teste sem transferir boot por TFTP: no U-Boot, `mmc dev 0`, `mmc read 0x1080000 0x2ae000 0x8000`, carregar apenas o DTB sd25m em `0x1000000`, limpar `bootargs` e `bootm 0x1080000`. Se `mmc read` nao aceitar o SD como device 0, usar `mmc list`/`mmc info` antes de ajustar o indice.

### 2026-07-27 - DTB 25 MHz elimina retries e receita Wi-Fi comprovada

- V19 foi lida diretamente da regiao boot do SD no U-Boot: `mmc dev 0` e `mmc read 0x1080000 0x2ae000 0x8000` leram 32.768 blocos sem erro; `md.b` confirmou `ANDROID!` em `0x1080000`.
- Com o DTB sd25m, o kernel nao apresentou nenhum retry CMD51/CMD1, montou as particoes imediatamente e configurou HDMI `2160p30hz` aos 18 segundos. A limitacao de 25 MHz resolveu o bloqueio/timing recorrente do SD nesta combinacao.
- O wrapper v19 executou, mas saiu com status 1. Copia temporaria do HAL revelou a dependencia ausente no namespace shell: `CANNOT LINK EXECUTABLE: library libnl.so not found`. A biblioteca existe em `/system/lib/vndk-28/libnl.so`.
- Receita manual comprovada: copiar o HAL vendor exato (267.564 bytes, SHA256 `5a05d99f2f1f4a5469c1e85a1678f266acc6a07352aad71bf95a5afbed467a5f`) para caminho sem `hal_wifi_default_exec` e executar com `LD_LIBRARY_PATH=/vendor/lib:/system/lib/vndk-28:/system/lib` no dominio shell.
- Com essa receita, o processo Wi-Fi permaneceu vivo, energizou/reinicializou o SDIO e registrou `android.hardware.wifi@1.0`, 1.1 e 1.2 `IWifi/default`. O Android concluiu autonomamente: `sys.boot_completed=1`, bootanim `stopped`, `service.bootanim.exit=1`, SystemControl e composer `running`, display `2160p30hz`.
- Ausencias de Bluetooth HCI e OMX Store ainda aparecem, mas nao impediram boot completo. Um warning de sysfs duplicado para `android_usb/android0` tambem nao foi fatal.
- V20 em preparacao: HAL Wi-Fi exato incorporado ao ramdisk como `/aquario-wifi-hal`, servico direto em shell e `LD_LIBRARY_PATH` VNDK explicito. A solucao final ainda deve incorporar a policy/namespace apropriados em vez do dominio shell permissivo.

### 2026-07-27 - v20 conclui boot autonomo e confirma Wi-Fi SV6051P

- O usuario identificou fisicamente o Wi-Fi como **SV6051P**. Preservar o conjunto proprietario original (modulos, firmware, blobs e HAL); nao substituir por HAL generico durante o bring-up.
- V20 concluida em `work/teste-khadas-fresh-20260727-wifi-vndk-v20/`:
  - HAL Aquario exato incorporado no ramdisk como `/aquario-wifi-hal`, root:root 0755, SHA256 `5a05d99f2f1f4a5469c1e85a1678f266acc6a07352aad71bf95a5afbed467a5f`;
  - servico `aquario.wifi-hal` iniciado por init em `u:r:shell:s0`, com `LD_LIBRARY_PATH=/vendor/lib:/system/lib/vndk-28:/system/lib`;
  - ramdisk `ramdisks/ramdisk-wifi-vndk-v20.img`, 4.975.388 bytes, SHA256 `46eef30843e4c0f0320c6dc2c10d509b92ddfe8167b3472c6328a81d45d23d34`;
  - boot `bootimgs/boot-khadas-fresh-p281-wifi-vndk-v20.img`, 13.469.696 bytes, SHA256 `137380eb4c9d44f84217fc1c147d490cee982db7f37d1adbfe00274eae5487c9`;
  - copia TFTP com nome `boot-khadas-fresh-p281-wifi-vndk-v20.img` e hash identico.
- Teste v20 por TFTP com o DTB SD 25 MHz foi inteiramente autonomo. Nao houve retries CMD51/CMD1; as particoes montaram de imediato e o HDMI mudou para `2160p30hz` por volta de 19 segundos.
- O servico `aquario.wifi-hal` permaneceu `running` como PID 2735, filho do init. Por volta de 143 segundos o SDIO foi reenumerado (`new high speed SDIO card at address 0001`, clock 50 MHz, barramento de 4 bits, `Set sdio wifi power up`) e o HAL registrou IWifi 1.0, 1.1 e 1.2.
- Por volta de 204 segundos: `sys.boot_completed=1`, `init.svc.bootanim=stopped`, `service.bootanim.exit=1`, `aquario.wifi-hal`, `system_control` e `vendor.hwcomposer-2-2` em `running`, display `2160p30hz`. O `lshal` confirmou IWifi 1.0/1.1/1.2 no PID 2735.
- Bluetooth HCI e OMXStore ausentes e o warning de sysfs duplicado `android_usb/android0` continuam nao fatais. SELinux permissivo e os dominios shell ainda sao temporarios; a imagem final deve recompilar policy/namespace.
- Proxima integracao solicitada: importar da imagem original Aquario a configuracao/driver do controle remoto. Primeiro comparar `remote.conf`, keylayouts, DTB IR e `CONFIG_*REMOTE*`/driver Amlogic com o kernel 4.9 atual; somente compilar driver novo se o suporte existente estiver ausente.

### 2026-07-27 - controle remoto Aquario recuperado no DTB

- O kernel #10 ja contem o driver necessario built-in: `CONFIG_AMLOGIC_REMOTE=y`, `CONFIG_AMLOGIC_MESON_REMOTE=y` e suporte IR blaster. No aparelho, `meson-remote` cria `aml_keypad` em `/dev/input/event1` e `/sys/class/remote/amremote`; portanto nao e preciso compilar outro driver.
- O DTB Khadas anterior carregava somente `khadas-ir`, custom code `0xff00`. Ao pressionar o controle Aquario, o kernel reportava quadros com custom code `0x4040` como `invalid custom`.
- A imagem Aquario original possui cinco mapas no DTB; um deles e `cyxtech-remote-cs918`, custom code `0x4040`. O `remote.conf` original tambem foi preservado, SHA256 `de706c6e786533d40ef0dfe43f6354426fac6a5c7baae1e21d3cae65c860a8fe`, mas seus codigos dinamicos `0xfb04`/`0xbd02` nao correspondem ao controle observado nesta unidade e nao foram necessarios.
- Gerado DTB de teste em `work/dtb-khadas-p281-systemroot-sd25-aquario-ir-v21/gxl_p281_1g_khadas_fstab_systemroot_sd25_aquario_ir.dtb`, 57.703 bytes, SHA256 `d95a34296725d2854eb6d4d13200d1f3d7873f0fc27abcf7ab793c0ee4ba120d`. Copia TFTP com nome identico e mesmo hash.
- Esse DTB preserva system-as-root e SD limitado a 25 MHz, substituindo somente o mapa Khadas pelos cinco mapas exatos do DTB Aquario original. Reextracao confirmou `mapnum=5`, codigos `0xdf00`, `0x4040`, `0xfe01`, `0xff00`, `0xdf20` e os keymaps completos.
- Teste real: kernel registrou `custom_number = 5` e todos os nomes/codigos esperados. `getevent -lt /dev/input/event1` recebeu corretamente `KEY_UP`, `KEY_DOWN`, `KEY_LEFT` e `KEY_RIGHT`, cada um com eventos DOWN/UP. Controle remoto funcional sem `remotecfg` e sem novo modulo.
- O boot usado nessa rodada veio da regiao raw do cartao e ainda era v19; por isso o wrapper Wi-Fi reiniciou com status 1. Isto nao regride a prova v20 por TFTP. Proximo passo e gravar o boot v20 no cartao e tornar o novo DTB persistente para boot sem TFTP.

### 2026-07-27 - cartao recebe v21 com v20 + DTB Aquario embutido

- Cartao confirmado no PC como `/dev/sdg`, Generic STORAGE DEVICE, 29,7 GiB, sem filesystem montado. Bootloader atual salvo em `work/card-v20-ir-20260727/bootloader-current-4m.bin`, SHA256 `e8f7d95a7eb9e26632110578a2b427866f9b3b9a92d72082357aaadb3f1a068a`.
- O `mkbootimg` do AOSP reproduziu o v20 sem DTB byte a byte, SHA256 `137380eb4c9d44f84217fc1c147d490cee982db7f37d1adbfe00274eae5487c9`. Isto validou todos os parametros do header antes da alteracao.
- Gerado v21 mantendo exatamente kernel, ramdisk e cmdline do v20 e adicionando o DTB Aquario IR/SD25 no campo Android `second`:
  - `work/card-v20-ir-20260727/boot-khadas-fresh-p281-wifi-vndk-ir-v21.img`;
  - 13.529.088 bytes, SHA256 `1787b597a54f9a061e6cd3f3683ce50c4cc58b3472801616747d8977167a360f`;
  - header: kernel 8.490.057, ramdisk 4.975.388, second 57.703, pagina 2.048;
  - o `second` extraido e byte a byte o DTB testado, magic FDT `d00dfeed`, SHA256 `d95a34296725d2854eb6d4d13200d1f3d7873f0fc27abcf7ab793c0ee4ba120d`;
  - copia TFTP `boot-khadas-fresh-p281-wifi-vndk-ir-v21.img` com hash identico.
- Backups antes da escrita: boot raw anterior de 16 MiB em `boot-before-v21-16m.img`, SHA256 `970ef83c9dd10ed1650f4edebe14361c5448e4f4ca97db8846cf2cef47b66bdd`; regiao DTB raw anterior de 256 KiB em `dtb-raw-before-v21-256k.bin`, SHA256 `50d41881760c1a8c3f8beab945abd2c86a0c1aaabc773752e5ce23571f8436a2`.
- V21 gravada na regiao boot do SD, setor inicial `0x2ae000`, particao raw de 16 MiB. Readback confirmou os primeiros 13.529.088 bytes exatamente iguais ao v21 e todo o restante zerado.
- O mesmo DTB foi gravado como recuperacao no setor raw `0x14000`, dentro da area reservada historicamente usada para DTB. Readback confirmou os primeiros 57.703 bytes e todo o restante dos 256 KiB zerado.
- Readback dos primeiros 4 MiB apos as escritas ficou byte a byte igual ao bootloader anterior; BL2/BL30/BL31/BL33 nao foram alterados.
- Proximo teste prioritario sem TFTP: no U-Boot, `mmc dev 0`, `mmc read 0x1080000 0x2ae000 0x8000`, limpar `bootargs` e `bootm 0x1080000`, deixando `0x1000000` sem DTB pre-carregado. Confirmar se o U-Boot carrega automaticamente o DTB do campo `second`. Se nao carregar, fallback comprovavel: `mmc read 0x1000000 0x14000 0x200` antes do `bootm`.

### 2026-07-28 - v21 inicia sem TFTP; incompatibilidade ARM32 do Wi-Fi isolada

- Teste real do v21 a partir do SD, com `0x1000000` zerado e sem TFTP, confirmou que o U-Boot encontra o DTB no campo `second`: primeiro informou ausencia de DTB legal em `0x1000000`, depois `load dtb from 0x34ba7b50`, `Single dtb detected`, e carregou kernel, ramdisk e Device Tree.
- Android 9 concluiu a inicializacao: `sys.boot_completed=1`, `init.svc.bootanim=stopped`, `service.bootanim.exit=1`; `aquario.wifi-hal`, `system_control` e `vendor.hwcomposer-2-2` ficaram `running`; HDMI em `2160p30hz`.
- `lshal` confirmou IWifi 1.0, 1.1 e 1.2 registrados pelo PID 2735 (`aquario-wifi-hal`). O SDIO enumerou o chip como `sdio:c07v3030d3030` e respondeu aos ciclos de energia, mas nao apareceu `wlan0`.
- Causa exata: os tres modulos da vendor (`ssv6051.ko`, `ssv6x5x.ko`, `ssv_hwif_ctrl.ko`) possuem `vermagic=4.9.y SMP preempt mod_unload modversions ARMv7`; o kernel #10 e AArch64 (`Linux 4.9.113`, ELF aarch64). `insmod` manual retornou `Exec format error`. SELinux estava permissivo e o shell tinha `CAP_SYS_MODULE`, portanto o bloqueio nao era policy/capability.
- O kernel #10 tambem tinha `CONFIG_CFG80211=y`, mas `CONFIG_MAC80211` desativado. O driver SSV ARM64 exige simbolos mac80211; e necessario habilitar `CONFIG_MAC80211=m`, reconstruir kernel/mac80211 e compilar os tres modulos Icomm contra o mesmo `Module.symvers`.
- Fonte exato baixado de `https://github.com/khadas/android_hardware_wifi_icomm_drivers_ssv6xxx`, branch `khadas-vims-pie`, commit `0dddfae`, em `work/ssv6xxx-khadas-vims-pie`. Primeiro build de `ssv6051.ko` no container correto produziu ELF AArch64/vermagic 4.9.y, mas os warnings de simbolos `ieee80211_*` confirmaram a dependencia mac80211 ausente.
- Pendencia estrutural separada: o Android ja inicia pelo conteudo do SD, mas ainda exige interromper o U-Boot e executar manualmente o `mmc read`/`bootm`; o boot automatico de energia continua por resolver.

### 2026-07-28 - v22: Wi-Fi ARM64, controle IR como teclado, HDMI 720p e Bluetooth desligado

- Hardware confirmado pelo usuario: esta unidade nao possui Bluetooth. O Android Aidan ainda anuncia `android.hardware.bluetooth` e BLE por XMLs em `/vendor/etc/permissions` e tenta iniciar `com.android.bluetooth`, embora nao exista `IBluetoothHci`.
- O controle Aquario ja gerava corretamente `KEY_UP`, `KEY_DOWN`, `KEY_LEFT` e `KEY_RIGHT`, mas `aml_keypad` tambem anunciava `BTN_MOUSE`, `EV_REL`, `REL_X`, `REL_Y` e `REL_WHEEL`. Isso fazia o Android classifica-lo simultaneamente como teclado e apontador. Essas capacidades de mouse foram removidas de `drivers/amlogic/input/remote/remote_core.c`; os mapas IR Aquario e todos os keycodes foram preservados.
- Kernel recompilado no container `android9-aquario-builder:latest`, com `-j16`, fonte `work/khadas-linux-pie-fresh-20260721` e saida `work/build-khadas-fresh-20260721/kernel-out`.
- Novo `Image.gz`: 8.502.471 bytes, SHA256 `b6043c0d6d2707a18a0a15693cdc8ea8b62c71b9c322ee9ad2801466b40af33e`.
- `CONFIG_MAC80211=m`, `CONFIG_MAC80211_LEDS=y` e `CONFIG_CFG80211_WEXT=y` estao ativos. `mac80211.ko` foi reconstruido junto ao kernel; os modulos Icomm previamente compilados continuam ABI-compativeis porque a mudanca do IR nao altera configuracao nem simbolos exportados.
- Modulos incorporados ao ramdisk, todos ELF AArch64 e `vermagic=4.9.y SMP preempt mod_unload modversions aarch64`, reduzidos com `aarch64-linux-android-strip --strip-unneeded`:
  - `mac80211.ko`: 1.030.528 bytes, SHA256 `9f1714c958387c686d1f7196c559fb9e21a8d5d0da04bc5c5e44194fc0fd026d`;
  - `ssv6051.ko`: 361.808 bytes, SHA256 `76f5ec3108ba4f9d6b0a6b0cbc3e3bc04c7e702bfffa6ea6eb43376f382a93eb`;
  - `ssv6x5x.ko`: 848.256 bytes, SHA256 `a4186a5ecb663568836e4436070f5f1f160b8080622f60e86ec14eb8dd3d6630`;
  - `ssv_hwif_ctrl.ko`: 13.672 bytes, SHA256 `c4ed40166342af2d7e4e8e3906b24b9385fc46df97b1d6a8bf992d3acd740c9f`.
- O wrapper `/init.aquario.wifi-v22.sh` carrega `mac80211`, `ssv6051`, `ssv6x5x` e `ssv_hwif_ctrl` nessa ordem e depois executa o HAL Aquario com o namespace VNDK comprovado. O servico recebeu `CAP_SYS_MODULE` e continua temporariamente em `u:r:shell:s0`/SELinux permissivo para bring-up.
- O cmdline agora inclui `hdmimode=720p60hz`. Um servico oneshot em `sys.boot_completed=1` tambem escreve `720p60hz` em `/sys/class/display/mode`, aplica `wm size 1280x720`, desliga `bluetooth_on` e desabilita `com.android.bluetooth` para o usuario 0.
- V22 gerada em `work/teste-khadas-fresh-20260728-wifi-ir-720p-nobt-v22`:
  - ramdisk: 5.622.387 bytes, SHA256 `bd9616e6a927936a8c76cca1e9c85de4a527efe9840ad920ac12561847d81b70`;
  - boot: 14.188.544 bytes, SHA256 `5ecb031a135fab772efdfb526bed875e60a7399b2929e4b0942de2a54328f011`;
  - DTB second: o mesmo Aquario IR/system-root/SD25 da v21, SHA256 `d95a34296725d2854eb6d4d13200d1f3d7873f0fc27abcf7ab793c0ee4ba120d`;
  - copia TFTP: `boot-khadas-fresh-p281-wifi-ir-720p-nobt-v22.img`, servidor `192.168.1.2`, hash identico.
- A imagem cabe na regiao boot raw de 16 MiB, com aproximadamente 2,59 MiB livres. Falta teste real da v22 e, depois, remover definitivamente os dois XMLs de feature Bluetooth da particao vendor para que `pm list features` nao anuncie hardware inexistente.

### 2026-07-28 - teste v22/v23: Android e 720p resolvidos; troca dos modulos vendor e o proximo passo

- V22 carregou os quatro modulos AArch64 com sucesso na primeira execucao, mas o HAL no rootfs ficou `0644` por regra do `mkbootfs` e falhou no `exec`. Nas tentativas seguintes, o wrapper tambem tratava `EEXIST` de modulos ja carregados como erro e reiniciava.
- V23 tornou a carga idempotente e instalou o HAL como `/sbin/aquario-wifi-hal`, onde o `mkbootfs` preserva modo executavel `0750` para root. Artefatos finais:
  - ramdisk: 5.759.329 bytes, SHA256 `e80347017eb859e00326e65848103246069bddfc1bf29ece3e6028a2a72b136e`;
  - boot: 14.325.760 bytes, SHA256 `f4224e5004c95287ffa1ff25dcf01bf3358844141400aabcfbebb0f71f4a2c97`;
  - TFTP: `boot-khadas-fresh-p281-wifi-ir-720p-nobt-v23.img` em `192.168.1.2`, hash identico.
- A primeira tentativa v23 teve retries CMD18 prolongados do SD, mas depois estabilizou. A repeticao apos reinicio montou system/vendor/produto/odm em cerca de 8 segundos sem retries CMD18; os retries CMD1 vistos eram apenas a sonda do slot eMMC fisicamente ausente.
- Android v23 concluiu em cerca de 59 segundos: `sys.boot_completed=1`, `aquario.wifi-hal=running`, bootanimation encerrada e postboot oneshot concluido.
- HDMI confirmado em `720p60hz`; `wm size` confirmou `Physical size: 1280x720` e o framebuffer passou a `dispdata(0,0,1279,719)`.
- Controle IR agora aparece com `Classes: 0x23`, em vez de `0x2b`: a classe de apontador/mouse foi removida e teclado/DPAD permanecem ativos em `/dev/input/event1`, usando `Generic.kl`.
- Bluetooth: `com.android.bluetooth` aparece em `pm list packages -d` e nao ha processo Bluetooth ativo, portanto o postboot desabilitou o pacote. As features `android.hardware.bluetooth` e `android.hardware.bluetooth_le` ainda aparecem porque os XMLs permanecem na particao vendor; remove-los no cartao e necessario.
- Wi-Fi: ao iniciar, os quatro modulos AArch64 carregaram e o HAL registrou IWifi. Quando o framework desligou o radio, `ssv_hwif_ctrl` foi removido normalmente. Ao executar `svc wifi enable`, o HAL energizou e reenumerou o SDIO, mas tentou recarregar os modulos ARM32 em `/vendor/lib/modules` e repetiu `Exec format error`, terminando com `Failed to load WiFi driver`.
- Inserir `ssv_hwif_ctrl.ko` manualmente muito depois da sequencia de energia nao resolveu: o probe CMD52 expirou com `-110`. A ordem correta depende do HAL carregar o modulo imediatamente apos energizar/reinicializar o SDIO.
- Proximo passo comprovado: colocar o cartao no PC e substituir `/vendor/lib/modules/ssv6051.ko`, `ssv6x5x.ko` e `ssv_hwif_ctrl.ko` pelas compilacoes AArch64 da v23. Tambem remover os dois XMLs de feature Bluetooth e gravar a boot v23 na regiao raw de 16 MiB. Depois, boot pelo cartao e teste `svc wifi enable`, criacao de `wlan0`, scan e conexao.
- Medicao de desempenho na v23 completa: load average `0.86`, CPU agregada 96% ociosa, temperatura 39 C, 986 MiB de RAM fisica, 575 MiB `MemAvailable`, zram 255 MiB praticamente sem uso. Nao ha saturacao de CPU, memoria ou temperatura em idle; a sensacao de peso vem do conjunto Android TV/GApps/Play Store para apenas 1 GiB e do custo grafico anterior em 4K. HDMI 720p ja esta ativo e as tres escalas de animacao foram reduzidas de 1.0x para 0.5x em runtime; aplicar 0.5x permanentemente na proxima revisao.

### 2026-07-28 - v24 gravada no SD: Wi-Fi ARM64 persistente e keylayout do controle corrigido

- Cartao confirmado como `/dev/sdg`, Generic STORAGE DEVICE removivel de 29,7 GiB. Assinaturas antes da edicao: boot `ANDROID!`, vendor e system ext4. A particao vendor foi verificada com `e2fsck -fn` apos as alteracoes, sem erros.
- Backup do boot raw anterior de 16 MiB: `work/card-20260728-v23-final/backups/boot-before-v23-16m.img`, SHA256 `323bec5e8cb16595ff294e172c0778a5f74c5563f3d7ce99b4875c80b3fdd7a9`. Backups dos modulos ARM32, XMLs Bluetooth, `modules.dep` e `Generic.kl` estao em `work/card-20260728-v23-final/backups/vendor/`.
- Causa adicional do controle identificada: o mapa IR cyxtech `0x4040` entrega o botao OK como codigo Linux 97 e HOME como 102, mas `Generic.kl` os traduzia para `CTRL_RIGHT` e `MOVE_HOME`. Foi instalado `/vendor/usr/keylayout/Vendor_0001_Product_0001.kl`, especifico para `aml_keypad` (vendor/product `0001:0001`), mudando somente 97 para `DPAD_CENTER` e 102 para `HOME`. DPAD, BACK, MENU, POWER e volume foram preservados.
- `/vendor/lib/modules` recebeu as quatro compilacoes AArch64/vermagic `4.9.y ... aarch64`: `mac80211.ko`, `ssv6051.ko`, `ssv6x5x.ko` e `ssv_hwif_ctrl.ko`. Hashes iguais aos modulos validados na v23. `modules.dep` agora declara mac80211 como dependencia dos dois drivers SSV e estes como dependencias do hwif. Os contextos SELinux `vendor_file` foram aplicados.
- Os XMLs `android.hardware.bluetooth.xml` e `android.hardware.bluetooth_le.xml` foram movidos para `/vendor/etc/permissions.disabled-aquario/`; o Android nao deve mais anunciar Bluetooth inexistente. O pacote Bluetooth continua desabilitado pelo postboot.
- V24 adiciona permanentemente as escalas de animacao `window`, `transition` e `animator` em 0.5, preservando kernel AArch64 #10, HDMI 720p, DTB Aquario IR/system-root/SD25, wrapper Wi-Fi idempotente e HAL original Aquario.
- Artefatos v24: ramdisk `work/teste-khadas-fresh-20260728-wifi-ir-720p-nobt-v24/ramdisks/ramdisk-wifi-ir-720p-nobt-v24.img`, 5.762.470 bytes, SHA256 `7bc25302e3f4b48dc49840cb57313705521bc2ba808fd50b8074f4d80de5d617`; boot `work/teste-khadas-fresh-20260728-wifi-ir-720p-nobt-v24/bootimgs/boot-khadas-fresh-p281-wifi-ir-720p-nobt-v24.img`, 14.327.808 bytes, SHA256 `98c9234920ec1c9ac3244ceecb5aec057c75698bf07bb36404c7e7866eb9c190`. Copia TFTP de hash identico em `openwrt/bin/targets/qualcommax/ipq50xx/`.
- A regiao boot raw, offset `1438646272` (setor `0x2ae000`), foi zerada nos 16 MiB e recebeu a v24. Readback da imagem foi identico, a cauda permaneceu zerada e `ANDROID!` foi confirmado. O primeiro 4 MiB/bootloader permaneceu byte a byte intacto, SHA256 `e8f7d95a7eb9e26632110578a2b427866f9b3b9a92d72082357aaadb3f1a068a`.
- Proximo teste no aparelho: bootar a v24 pelo SD, confirmar `sys.boot_completed=1`, pressionar OK/HOME/DPAD/BACK no controle, executar `svc wifi enable`, verificar `wlan0`, scan e associacao. O Wi-Fi ainda precisa deste teste fisico de timing SDIO; o controle precisa do teste dos botoes reais. O boot automatico do U-Boot continua uma pendencia separada caso ainda exija `mmc read`/`bootm` manual.

### 2026-07-28 - v25: Wi-Fi SSV6051P funcional e manutencao remota comprovada

- A v25 corrigiu o ultimo erro do Wi-Fi: o wrapper entregava ao driver o nome completo do firmware, mas o driver acrescentava o nome novamente. `cfgfirmwarepath` agora aponta somente para o diretorio `/vendor/etc/wifi/ssv6051/`.
- `ssv_hwif_ctrl` recebeu fallback Cabrio quando a primeira leitura do chip ID retorna `0xff`. O modulo AArch64 final tem SHA256 `fe49391037e0836e3460e6850974a3efcae719d031b5b32788d0aea2988f4049`.
- Teste real confirmou o SSV6051P/RSV6200A0-201311, MAC `58:04:54:0e:25:24`, firmware `ssv6051-sw.bin` versao 13784 com verificacao OK, `wlan0` ativa, `wpa_supplicant` rodando e scans nos canais 1 a 14. O Wi-Fi deixou de ser pendencia de driver.
- Android concluiu o boot com `sys.boot_completed=1`, HDMI `720p60hz` e Ethernet fixa `192.168.1.139/24`, gateway `192.168.1.2`. O aparelho nao possui eMMC: sistema e boot estao integralmente no cartao SD.
- Artefatos v25: ramdisk 5.763.330 bytes, SHA256 `894ea4b722cc423ef6df11cb5d49a00c2859015b69cd5102753dcb90097695c9`; boot 14.329.856 bytes, SHA256 `9007f23fb4e9720fc14e6c3ca55f9580ad771d27f0eb4df0b853c679d5c29f9a`.
- Dropbear multicall estatico foi recompilado no container OpenWrt correto com `make -j16 STATIC=1 MULTI=1`, ELF AArch64 de 1.410.824 bytes, SHA256 `0791dfa7440e209926cd868f83e475026273fe16697132fa4c753fd98730a5ad`.
- SSH root foi validado no Android pela porta interna 2222. SCP legado foi testado nos dois sentidos com `scp -O`; os tres hashes foram identicos (`cd5aed55cd56995b9aa940f79671f8672b656285eacd28f57bdbf3dd17cb6688`). OpenSSH recente tenta SFTP por padrao, mas esta ROM nao possui `/usr/libexec/sftp-server`.

### 2026-07-28 - Invade/MikroTik: NAT e VRF permanentes para SSH do Aquario

- O roteador deve ser acessado exclusivamente pelo container em `/media/dados_2tb/opw/invade`, usando `docker compose run --rm router-analyzer` e `configs/inventory.json`. Alvo MikroTik: `192.168.1.254`.
- Acesso da estacao `192.168.1.10`: `ssh -i ~/.ssh/id_temp_aquario -p 2223 root@192.168.1.254`. O DNAT entrega no Android `192.168.1.139:2222` pela ether8.
- Regras auditadas pelo container: connection-mark `aquario-ssh`; requisicoes marcadas para `mr80x-recovery`; respostas recebidas pela ether8 marcadas para `main`; source NAT para `192.168.1.2`; DNAT externo 2223 para interno 2222; filtro `accept connection-mark=aquario-ssh` antes do FastTrack.
- O acesso ADB equivalente permanece em `192.168.1.254:5555 -> 192.168.1.139:5555`. A porta 2222 externa continua reservada ao OpenWrt MR80X; por isso o Aquario usa 2223 externamente.

### 2026-07-28 - v26 gravada: SSH/SCP persistentes no ramdisk

- A v26 deriva byte a byte da arvore v25 e acrescenta `/sbin/dropbearmulti` estatico, links `dropbear`, `dropbearkey`, `scp` e `dbclient`, alem da chave publica de manutencao embutida em `/aquario-ssh/authorized_keys`.
- Novo servico `aquario.ssh` em `init.amlogic.rc` inicia quando `sys.boot_completed=1`. O script `/init.aquario.ssh-v26.sh` cria `/data/ssh/.ssh`, preserva ou gera a chave host Ed25519, instala `authorized_keys` se ausente e executa Dropbear em foreground na porta 2222, sem senha, sob supervisao do `init`.
- Para SCP a partir deste PC e necessario `scp -O -P 2223 -i ~/.ssh/id_temp_aquario ... root@192.168.1.254:...`; o `-O` seleciona o protocolo SCP legado suportado pelo multicall.
- Ramdisk v26: `work/teste-khadas-fresh-20260728-wifi-ir-720p-nobt-v26/ramdisks/ramdisk-wifi-ir-720p-nobt-ssh-v26.img`, 6.349.642 bytes, SHA256 `1afd18a49d68c57904e00c21bff306e687d27e98418ff96dc0fd767bc8707faa`.
- Boot v26: `work/teste-khadas-fresh-20260728-wifi-ir-720p-nobt-v26/bootimgs/boot-khadas-fresh-p281-wifi-ir-720p-nobt-ssh-v26.img`, 14.915.584 bytes, SHA256 `c0ca87f7c6859e6e9c93d1dbcb7522c16ee20e4fe442fc04413dc449ac6d1980`. Copia TFTP de hash identico em `openwrt/bin/targets/qualcommax/ipq50xx/`.
- A imagem deixa 1.861.632 bytes livres na regiao boot raw de 16 MiB. O boot v25 anterior foi salvo integralmente em `work/teste-khadas-fresh-20260728-wifi-ir-720p-nobt-v26/backups/boot-before-v26-16m.img`, SHA256 `380662301f6b6a35da47a652ddfc83c0c14a5f78cdd6f678f5d5bcc54fbafe2f`.
- A v26 foi gravada remotamente no `/dev/block/boot` do cartao. Readback dos 14.915.584 bytes confirmou exatamente o SHA da imagem; a cauda zerada de 1.861.632 bytes confirmou SHA256 `e762d0479b15db6916fad69d904b41d3ac345c43e19104323a44052c6436a58a`.
- Proximo teste: reiniciar, executar o boot manual pelo U-Boot se ainda necessario e confirmar que SSH e SCP retornam sozinhos por `192.168.1.254:2223`. Tambem verificar se a alteracao persistente de `/system/etc/prop.default` (`ro.secure=0`, `ro.debuggable=1`) torna o ADB root apos o reboot.

### 2026-07-28 - teste real v26 aprovado

- Reboot completo confirmou BL2/BL31/U-Boot carregados do SD. O boot Android ainda precisou dos comandos manuais `mmc dev 0`, `mmc read 0x1080000 0x2ae000 0x8000`, `setenv bootargs`, `bootm 0x1080000`.
- U-Boot reconheceu a v26, extraiu automaticamente o DTB no campo `second` e iniciou `Linux 4.9.113` build #12 em AArch64. Android concluiu com `sys.boot_completed=1`; Wi-Fi voltou a criar `wlan0` e escanear; o postboot terminou em `720p60hz` e `1280x720`.
- O servico persistente foi aprovado: `init.svc.aquario.ssh=running`, PID pai do Dropbear = 1, executavel real `/sbin/dropbearmulti`, UID/GID root e porta interna 2222. O acesso externo voltou sozinho em `192.168.1.254:2223` pelas regras Invade/MikroTik.
- SCP v26 foi novamente testado nos dois sentidos usando `/sbin/scp`, hash local, remoto e retorno `bbdcf1fc5785bc81149a54d8fec910e81fbd02dfb3e9636b781665c23ce55843`. O link temporario `/system/bin/scp` da v25 foi removido; portanto o resultado comprova exclusivamente o ramdisk v26.
- Props apos reboot: `ro.secure=0`, `ro.debuggable=1`, `ro.adb.secure=1`. `adb root` responde que reinicia e define `service.adb.root=1`, mas o binario adbd desta ROM continua executando como UID/GID 2000. Isso nao bloqueia mais manutencao: SSH oferece root real e SCP permite substituir arquivos e imagens sem remover o cartao.

### 2026-07-28 - v27: U-Boot do Aquario corrigido para boot automatico pelo SD

- O ambiente persistido continha `bootcmd=run start_autoscript; run storeboot`, mas este U-Boot procura o ambiente no eMMC ausente antes de inicializar o SD e, por isso, usava o ambiente compilado. No BL33 descriptografado, o default real era `bootcmd=run storeboot` com `storeboot` apontando para `imgread kernel`, tambem dependente do eMMC.
- Backups anteriores a alteracao: `work/uboot-auto-sd-v27-20260728/backups/bootloader-before-auto-v27-4m.bin`, SHA256 `e8f7d95a7eb9e26632110578a2b427866f9b3b9a92d72082357aaadb3f1a068a`; e `env-before-auto-v27-8m.bin`, SHA256 `0454e9e43f8a1e27bf63a42078c47b65d7b0373eef7024b612bb18afd90a3993`.
- O `gxlimg` foi baixado da fonte primaria `https://github.com/repk/gxlimg.git`, commit `d7a8d33ef7d330a8dc77f3f53ab1e12b00a6ec8f`, e compilado no container `openwrt-25.12-builder-noble:latest` como root com `make -j16`.
- O layout Aquario possui um intervalo adicional de 512 bytes antes do FIP: FIP em `0xc200`, enquanto o `gxlimg` espera `0xc000`. Apos normalizar esse intervalo, foram extraidos BL2 49.152 bytes, BL30 54.784, BL31 181.760 e BL33 criptografado 418.816 bytes.
- O BL33 descriptografado usa container Amlogic `LZ4C`. Foi criado `scripts/aml_lz4c.py`, baseado em `liblz4.so.1`, que valida magic, tamanhos, SHA256 do payload e SHA256 do cabecalho, e recompata com LZ4 HC nivel 12 e padding de 512 bytes. O roundtrip reproduziu exatamente o U-Boot original de 781.600 bytes, SHA256 `b25c1d7fefae7ab733f8166b8a4ebf916f191555c6979d0f1d8c9ff599d3a`.
- Foi criado `scripts/patch_uboot_env_fixed.py` para substituir uma unica entrada do ambiente compilado sem alterar seu tamanho. `storeboot` passou a executar `mmc dev 0;mmc read 0x1080000 0x2ae000 0x8000;setenv bootargs;bootm 0x1080000`, preenchendo o restante do slot fixo com espacos. U-Boot cru corrigido: SHA256 `051780f8346fb54f81aadd7c5cc824c5fe28951f03ad868a11d8edc8ca4b02f2`.
- Candidato final `work/uboot-auto-sd-v27-20260728/bootloader-auto-sd-v27-4m.bin`, SHA256 `4e410ab037633c5fb092c03593fc388f73a3e8edb02e4c64542691e4dafdf44a`. Somente o BL33 mudou; BL2, cabecalho FIP, BL30, BL31 e o restante permaneceram identicos. Reextracao, descriptografia e descompressao do candidato reproduziram exatamente o U-Boot corrigido.
- A imagem foi gravada remotamente em `/dev/block/bootloader`; o readback dos 4 MiB foi identico. Dois reinicios sem entrada TTL confirmaram boot automatico: U-Boot seleciona `mmc0`, le os 32.768 blocos desde `0x2ae000`, reconhece a Android boot image, inicia o kernel e o SSH retorna sozinho.

### 2026-07-28 - v28: HDMI por EDID, 4K30 seguro e logo Android

- A EDID do display HJW/MACROSILICON marca `720p60hz` como nativo, anuncia modos ate `2160p60hz`, possui TMDS maximo de 300 MHz e nao anuncia SCDC. Para o S905W, a selecao automatica segura prioriza `2160p30hz`, `2160p25hz`, `2160p24hz`, `1080p60hz`, `1080p50hz` e finalmente `720p60hz`.
- O script de postboot agora le `/sys/class/amhdmitx/amhdmitx0/disp_cap`, escolhe o maior modo seguro, escreve `/sys/class/display/mode` e registra `persist.aquario.hdmi.mode`. Em 4K, a interface Android e renderizada em 1920x1080 para evitar o custo de compositor 4K em apenas 1 GiB; em 720p usa 1280x720.
- Artefatos v28: ramdisk `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v28/ramdisks/ramdisk-wifi-ir-auto-hdmi-ssh-v28.img`, 6.350.347 bytes, SHA256 `3881dff1eedaa5e3dcb18b0cfd8dc4b719d2346977d586e1892aaeb9573acc66`; boot `bootimgs/boot-khadas-fresh-p281-wifi-ir-auto-hdmi-ssh-v28.img`, 14.915.584 bytes, SHA256 `d0aeababda626f847884e3aae7118005e0cc70d2b1a708df5a1117736b23034d`. Copia TFTP de hash identico em `openwrt/bin/targets/qualcommax/ipq50xx/`.
- Backup anterior: `backups/boot-before-v28-16m.img`, SHA256 `42a3871691457feda7baec59cd66004b6b1da61463968742a52403280a38f4a9`. Gravacao e readback remotos foram identicos; a cauda zerada preservou SHA256 `e762d0479b15db6916fad69d904b41d3ac345c43e19104323a44052c6436a58a`.
- Teste real v28 aprovado: boot automatico, `sys.boot_completed=1`, SSH root ativo, `/sys/class/display/mode=2160p30hz`, `persist.aquario.hdmi.mode=2160p30hz` e `vendor.display-size=3840x2160`. O link HDMI esta efetivamente em 3840x2160 a 30 Hz. O SurfaceFlinger ainda declara base 1280x720 e override 1920x1080; alinhar a geometria base antes da inicializacao do framework e a proxima correcao de display.
- O Aidan `/system/media/bootanimation.zip`, SHA256 `42e4af31cb843657f71996f8eb31ff0ca0c074e3757aa213e54ce4b203b5a413`, foi preservado em `work/android-logo-display-v28/backups/bootanimation-aidan.zip` e renomeado no Android para `bootanimation-aidan.disabled.zip`. Sem o ZIP customizado, o BootAnimation do AOSP usa os assets internos oficiais `android-logo-mask.png` e `android-logo-shine.png`; o processo bootanim executou durante o reboot v28.
- O scan bruto do SV6051P esta correto: detectou `Tassotti` em 2,4 GHz com sinal em torno de -30 dBm. O BSS de SSID vazio `0a:8a:f1:02:35:d8` contem `MESH ID: tassotti-mesh`, portanto e o BSS de malha oculto e nao defeito de leitura do driver.
- O load average alto nao representa saturacao de CPU. As tarefas em estado D sao `videosync` e as quatro threads `ssv6xxx_encrypt_task` do driver Wi-Fi, todas paradas em seus loops de kernel; e necessario medir a responsividade e I/O do SD separadamente antes de atribuir a elas os travamentos percebidos.

### 2026-07-28 - v29 a v31: HDMI autodetectavel com interface 1080p real

- O `systemcontrol` proprietario ja implementa selecao automatica por EDID. No display de teste ele escolhe `2160p30hz`, configura `444,8bit`, publica `vendor.display-size=3840x2160` e limita corretamente o modo por TMDS/SCDC. A falha era uma corrida: o HWC iniciava antes da propriedade. A v29 tornou `vendor.hwcomposer-2-2` disabled e o inicia somente depois de `vendor.display-size`; em telas 4K a propriedade entregue ao compositor e limitada a 1920x1080.
- V29: ramdisk 6.350.133 bytes, SHA256 `41010745c29689c945464faae8cf6921d453dfeb20814b3fb29e299804c236ca`; boot 14.915.584 bytes, SHA256 `1a3256efaa6891e2a3b738a4aec682f42e71c54ea3d25f807151085077a6ffd5`. Backup anterior de 16 MiB: SHA256 `e92e8dd309acb1961f86f266904966d53c90f4b9555e2b22a2e98360a66f2aa1`.
- O framebuffer continuou 720p porque `/vendor/etc/mesondisplay.cfg` continha `MBOX gxl 720p`. O original foi salvo como `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v29/backups/mesondisplay-v29-original.cfg`, SHA256 `6c8333770f77ab09727ab7d8e7a13a5214dd665e63dacbcaaed4d75d23dd1bf1`. A vendor ativa agora usa `MBOX gxl 1080p`, SHA256 `764c8ddd3b6e24e959a8a0a879aa1f0e3d0d2d90bd5d67729ca1c4b8cf147a38`.
- A configuracao vendor fez `systemcontrol` publicar 1920x1080, mas o kernel ainda criava 1280x720 porque o DTB continha `display_mode_default="720p60hz"`, `display_size_default=<1280 720 1280 2160 32>` e apenas 11 MiB para fb0.
- A v30 alterou somente tres propriedades de `/meson-fb`: `mem_size=<0x400000 0x1800000 0x100000>`, `display_mode_default="1080p60hz"` e `display_size_default=<1920 1080 1920 3240 32>`. Esses valores seguem a referencia GXL 1080p da propria arvore Khadas. DTB final: 57.703 bytes, SHA256 `52a159b9bf1d4a27a94ea7613d2aec77f3b8246237fb48d7e92046bc06b72f47`; boot v30: SHA256 `86c03cdb6f56f074eea42d427bd267a5694c1fd2e7792236ba176e1e73eb4005`. O kernel confirmou fb0 de 24 MiB, `1920x3240`, sem falha CMA.
- A fonte primaria do HWC foi arquivada em `work/hwcomposer-khadas-vims-pie-20260728`, repositorio `https://github.com/khadas/android_hardware_amlogic_hwcomposer.git`, branch `khadas-vims-pie`, commit `94396709f4393f0f01c92c8572e3824175ef446b`. O blob Aquario foi preservado em `blobs-aquario/hwcomposer.amlogic.so`, SHA256 `1cdbf2f132894bd41ad6ca04ea337d34644dfef50260a02ea2b53f34a3270c35`.
- A desmontagem do simbolo `HwcConfig::getFramebufferSize` mostrou que esta variante do blob le `vendor.ui_mode`; sem propriedade retorna 1280x720, e com valor curto `1080` retorna 1920x1080. O teste em runtime confirmou o log `HwcConfig::default frame buffer size (1920 x 1080)`.
- A v31 define `vendor.ui_mode=1080` em `early-init`, antes de HWC e SurfaceFlinger. Ramdisk v31: 6.350.261 bytes, SHA256 `1fcdc3a2b02c3cc534e54ad92b3a18d7b2866164ab2f3e0ac035cd3455687f38`; boot v31: 14.915.584 bytes, SHA256 `e8c9de2bc44a0fd5cd5396da30e8d85669dc8f75ad1627135c03f8928148669b`. Copia TFTP de hash identico em `openwrt/bin/targets/qualcommax/ipq50xx/`.
- Teste final v31 aprovado sem intervencao TTL: boot automatico, Android completo, SSH ativo, `fb0=1920x3240`, modo fb `1920x1080`, HWC 1920x1080, SurfaceFlinger fisico/logico 1920x1080, eixos de escala `0 0 1919 1079` para janela HDMI `0 0 3839 2159`, e sinal HDMI `2160p30hz`. A interface agora e renderizada em 1080p real e ampliada por hardware para a maior saida segura detectada.
- Apos a reserva adicional do fb0, `MemAvailable` permaneceu acima de 400 MiB e zram quase livre. Wi-Fi, SSH e demais servicos continuaram ativos; nao houve OOM nem erro de alocacao CMA.

### 2026-07-28 - provisionamento concluido e ambiente U-Boot persistente corrigido

- O aparelho ainda estava com `device_provisioned=0` e `user_setup_complete=0`; `com.google.android.tungsten.setupwraith/.MainActivity` permanecia como atividade ativa e HOME. Isto mantinha SetupWraith, Play Store e varios processos GMS acordando juntos, causando a sensacao de lentidao logo apos o boot.
- Foram definidos `device_provisioned=1`, `user_setup_complete=1` e `tv_user_setup_complete=1`; `com.google.android.tungsten.setupwraith` foi desabilitado somente para o usuario 0. `com.google.android.tvlauncher/.MainActivity` passou a ser HOME e atividade retomada. Play Store, GMS e configuracoes foram preservados.
- Durante a troca ao vivo de HWC/SurfaceFlinger/launcher ocorreu um unico crash do SystemUI por `glGenTextures error! GL_OUT_OF_MEMORY`. O SystemUI reiniciou sozinho. Dois boots limpos posteriores da v31 nao registraram qualquer entrada no buffer `crash`, confirmando que o evento foi causado pelas varias reinicializacoes graficas em runtime, nao pelo framebuffer 1080p normal.
- Em idle assentado, `vmstat` mostrou 96-98% de CPU ociosa e zero I/O na maior parte das amostras. O load average alto vem das threads `videosync` e `ssv6xxx_encrypt_task` em estado D, mas elas ficam bloqueadas nos loops de espera do driver e nao consomem CPU. O maior custo perceptivel continua sendo a latencia do cartao SD durante lancamento/atualizacao de aplicativos.
- Um reboot parou no prompt porque o ambiente persistente valido ainda continha `bootcmd=run start_autoscript; run storeboot` e `storeboot=if imgread kernel ${boot_part}...`, dependentes do eMMC ausente. O U-Boot embutido corrigido da v27 era usado somente quando esse ambiente nao era carregado.
- Backup do ambiente antes da correcao: `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v31/backups/env-after-systemcontrol-v31-8m.bin`, SHA256 `0454e9e43f8a1e27bf63a42078c47b65d7b0373eef7024b612bb18afd90a3993`. O parser `fw_printenv` confirmou CRC valido e 78 variaveis.
- O ambiente foi exportado com `fw_printenv`, alterado para `bootcmd=run storeboot` e `storeboot=mmc dev 0;mmc read 0x1080000 0x2ae000 0x8000;setenv bootargs;bootm 0x1080000`, e reconstruido com `mkenvimage -p 0x00 -s 0x10000`. `bootdelay=1` foi preservado para permitir acesso TTL.
- Ambiente de 64 KiB final: `env/env-auto-sd-v31-64k.bin`, SHA256 `ffad4927e439cfa3033386ccddea02946ea27e9c60fef8f468e611546db1867b`. Imagem composta de 8 MiB: `env/env-auto-sd-v31-8m.bin`, SHA256 `c64a7af517c3a09cf437825b75bf4f6c1dbd80534500a08157fcca3239916e5a`; todos os bytes depois de `0x10000` permaneceram identicos ao backup.
- Somente os primeiros 64 KiB de `/dev/block/env` foram gravados. Readback de 64 KiB e da particao completa confirmou ambos os hashes esperados.
- Teste final sem entrada TTL aprovado: apos a contagem de um segundo, U-Boot executou automaticamente `mmc dev 0`, leu 32.768 blocos desde `0x2ae000`, reconheceu a v31, carregou o DTB embutido e iniciou o kernel. Android concluiu em cerca de 56 segundos, SSH retornou, launcher Android TV abriu direto, `fb0=1920x3240`, SurfaceFlinger 1920x1080, HDMI `2160p30hz`, Wi-Fi/HAL ativos e nenhum crash no boot limpo.

### 2026-07-28 - bootanimation Android explicita para v31

- O fallback interno do BootAnimation foi executado sem `/system/media/bootanimation.zip`, mas nao ficou visivel no HDMI. O log mostrou repetidamente `BufferLayerConsumer [BootAnimation#0] syncForReleaseLocked: failed to flush RenderEngine`; portanto a execucao do processo, sozinha, nao comprovava imagem visivel.
- Foi criado um pacote explicito em `work/android-logo-display-v31-explicit/bootanimation.zip`, usando o wordmark oficial `android-logo-mask.png` da arvore AOSP 9. O quadro e 1920x1080, fundo preto e texto branco centralizado; `desc.txt` usa 30 fps e repete o quadro ate o Android encerrar o bootanim.
- As entradas do ZIP estao sem compressao, conforme o formato esperado pelo BootAnimation. Tamanho final 60.402 bytes, SHA256 `8df5dbb91786768a3a7af34f7d138c702ae297868a39bca4e98b72eadbcebf4e`; `unzip -t` aprovou o pacote.
- O arquivo foi instalado em `/system/media/bootanimation.zip` com owner `root:root`, modo 0644 e contexto `u:object_r:system_file:s0`. O hash lido no aparelho e identico ao artefato local.
- O reboot concluiu automaticamente e o SSH retornou com `sys.boot_completed=1` em 26 segundos. Depois, o bootanim foi iniciado de forma controlada com o Android ativo e uma captura de tela foi feita durante sua execucao: `work/android-logo-display-v31-explicit/bootanim-live-test.png`, 1920x1080, SHA256 `38670481063e505ad39b636e4b46c3e36dd9a7841cdf70fad51f6e42ff082770`. A captura comprova o wordmark branco inteiro e centralizado na camada composta.
- O log ainda registra `syncForReleaseLocked: failed to flush RenderEngine` em cada quadro, mas isso nao impede a composicao capturada. Resta confirmar externamente se o quadro chegou ao painel HDMI durante o reboot/teste ao vivo.

### 2026-07-28 - diagnostico somente leitura da interface lenta

- Nenhuma configuracao foi alterada durante o diagnostico. Em dez amostras de `vmstat`, a CPU ficou entre 80% e 97% ociosa na maior parte do tempo; os quatro Cortex-A53 estavam online, governor `interactive`, 1,2 GHz na leitura, e a temperatura do SoC era apenas 44 C. Nao ha throttling nem saturacao de CPU.
- Memoria tambem nao e o gargalo imediato: `MemAvailable` ficou em torno de 423 MiB; zram tinha somente 16 MiB de 256 MiB ocupados e `dumpsys meminfo` classificou o estado como normal.
- O culpado dominante da sensacao continua e o refresh: a saida fisica esta em `2160p30hz`, e DisplayManager, SurfaceFlinger e HWC expoem para a interface somente 1920x1080 a 30,0 fps, com periodo de VSYNC de 33.333.333 ns. Portanto cursor e animacoes ficam limitados a 30 atualizacoes/s; um prazo perdido produz intervalo proximo de 66 ms.
- `dumpsys gfxinfo` do TV Launcher mediu 597 frames, 155 janky (25,96%), percentis 50/90/95/99 de 9/38/57/300 ms e 252 ocorrencias de alta latencia de entrada. Isso confirma objetivamente a sensacao visual. O pipeline e Skia OpenGL sobre Mali-450 MP; o launcher e composto como uma camada Client 1920x1080, enquanto o cursor usa uma camada HWC Cursor separada.
- A GPU oscilou de 500 a 666 MHz; durante a interface o pixel processor marcou aproximadamente 22% a 69%. Os frames comuns do launcher terminam perto de 9 ms, logo nao ha evidencia de GPU permanentemente saturada, embora 1080p tenha custo relevante neste Mali-450.
- O cartao e um SD `SC32G` e usa scheduler `noop`. No intervalo ocioso de 10 s, nao houve leitura e ocorreram apenas seis pequenas escritas, sem espera relevante; nao e a causa da animacao continuamente lenta naquele momento. Historicamente desde o boot, porem, o SD acumulou latencias altas e continua sendo o principal agravante ao abrir/instalar aplicativos.
- Play Store, `vending:download_service`, Package Installer, GMS, Katniss, TV Recommendations, Settings e explorador estavam residentes simultaneamente. Eles aumentam memoria e I/O em uma caixa de 1 GiB, mas a CPU estava ociosa e nao sustentavam carga suficiente para explicar o cursor travado.
- As cinco tarefas em estado D (`videosync` e quatro `ssv6xxx_encrypt`) continuam inflando o load average, mas nao consomem CPU. Nao devem ser usadas como indicador de lentidao.
- Conclusao: para fluidez da GUI, o primeiro experimento futuro deve comparar `1080p60hz` mantendo framebuffer/interface 1920x1080. A selecao atual prioriza resolucao HDMI maxima (`2160p30`) e sacrifica fluidez. Nenhuma mudanca foi feita nesta rodada.

### 2026-07-28 - cliques e botoes sem resposta: entrada desconectada

- O launcher estava focado, visivel e com regiao tocavel completa 1920x1080. InputDispatcher estava habilitado, nao congelado, sem evento pendente, filas de entrada/saida vazias e conexao do launcher em estado `NORMAL`. Nao houve ANR desde o boot.
- O hub USB apareceu como `usb 1-2`, contendo teclado `CASUE USB KB` nas portas/interfaces 1-2.1 e mouse `Razer Abyssus 2000` em 1-2.4. O InputReader registrou inicialmente `Detected input event buffer overrun` para o mouse.
- Em uptime 524,264 s, o kernel registrou `usb 1-2: USB disconnect`; teclado e mouse foram removidos em seguida. O sumico ocorreu no hub pai inteiro, nao apenas no driver do mouse. Nao havia mensagem de erro xHCI, timeout ou overcurrent associada, compativel com desconexao fisica ou perda de alimentacao do hub.
- Na verificacao atual, `/proc/bus/input/devices`, `getevent -lp` e `dumpsys input` nao continham teclado nem mouse USB. Permaneciam apenas `gpio_keypad`, `aml_keypad`, `aml_vkeypad`, `cec_input` e `virtual-search`. O CEC anuncia somente `KEY_POWER`.
- Uma captura `getevent -lt` de 15 segundos enquanto o usuario tentou interagir recebeu zero eventos. Assim, os cliques/botoes sem resposta naquele instante nao eram lentidao do launcher ou erro de coordenadas: nenhum evento chegava ao kernel. O controle original continua sem mapa/driver funcional, e o mouse depende de o hub USB permanecer enumerado.
- Nenhuma configuracao foi alterada nesta verificacao.

### 2026-07-28 - captura interativa do controle IR de 13 botoes

- A captura foi feita em `/dev/input/event1` (`aml_keypad`) com `getevent -lt`, um botao por vez. Direcionais: UP=`KEY_UP`, DOWN=`KEY_DOWN`, LEFT=`KEY_LEFT`, RIGHT=`KEY_RIGHT`; todos corretos. BACK/VOLTAR=`KEY_BACK`, tambem correto.
- O botao OK esta errado: emite `KEY_RIGHTCTRL`, quando deveria emitir `KEY_OK` ou `KEY_ENTER`. Esta e a causa direta de navegar ate um item e nao conseguir seleciona-lo.
- HOME emite `KEY_HOME`; para a acao HOME global do Android TV o codigo adequado e `KEY_HOMEPAGE`. O mapeamento atual pode ser interpretado apenas como inicio da linha/lista.
- PLAY/PAUSE esta errado: emite `KEY_MENU`, quando deveria emitir `KEY_PLAYPAUSE`.
- VOLUME UP produz scancode bruto `0x24` e VOLUME DOWN produz `0x23`; ambos estao `undefined` no mapa ativo e nao geram `EV_KEY` para o Android.
- O botao MOUSE produziu scancode bruto decimal 71 (`0x47`) marcado `undefined` nesse quadro IR e tambem nao gera `EV_KEY`. O mesmo valor numerico aparece no mapa A95X como LEFT, indicando que e necessario preservar/verificar tambem o custom code do quadro antes de editar a tabela.
- O DTB v31 ainda contem os cinco mapas genericos Cyxtech importados. No mapa `cyxtech-remote-a95x`, custom code `0xdf00`, os scancodes conhecidos explicam os erros atuais: `0x06 -> KEY_RIGHTCTRL`, `0x42 -> KEY_HOME`, `0x18 -> KEY_MENU`; os volumes previstos por esse mapa eram `0x5d/0x5c`, diferentes dos `0x24/0x23` emitidos pelo controle real.
- O botao de funcao desconhecida ainda nao foi capturado: duas janelas de captura terminaram sem evento. Tambem falta confirmar o decimo terceiro botao (a lista verbal continha doze funcoes, possivelmente faltou POWER).
- Nenhuma tabela de teclas ou imagem foi modificada nesta etapa; os dados servem para construir o mapa IR correto depois de completar a captura.

### 2026-07-28 - varredura do botao IR desconhecido abaixo do decodificador

- Duas capturas do log do `meson-remote` e uma captura de `/dev/input/event1` nao produziram scancode nem `EV_KEY` quando o botao desconhecido foi pressionado.
- Para separar botao sem emissao de quadro nao reconhecido, foi medido diretamente o IRQ 24 `keypad`, usado pelo receptor IR. Um unico toque elevou o contador de 1512 para 1612: delta de 100 interrupcoes.
- Portanto o LED do controle transmite e o receptor da placa detecta o trem de pulsos. O driver vendor, configurado com protocolo `0x1` e mapas de custom code NEC, nao consegue transformar esse trem em quadro/scancode valido. O botao nao esta morto; provavelmente usa protocolo, custom code ou formato especial diferente dos demais.
- O driver vendor nao expoe captura de pulsos brutos em `/sys/class/remote/amremote`. Para identificar o codigo completo sera necessario instrumentar temporariamente o `meson-remote` no kernel para registrar duracoes/registradores antes da validacao, ou medir a saida do receptor com analisador logico. Nenhuma configuracao foi alterada nesta medicao.

### 2026-07-28 - botao desconhecido decodificado pelo modo learning original

- A conclusao anterior sobre ausencia de captura bruta foi corrigida apos ler o codigo-fonte original em `drivers/amlogic/input/remote/sysfs.c`: os atributos existem em `/sys/class/remote/amremote/` quando o caminho e listado seguindo o symlink. O driver oferece `ir_learning`, `learned_pulse`, `debug_enable`, `debug_log`, `receive_scancode` e tabelas carregadas.
- `ir_learning=1` troca temporariamente o receptor para `REMOTE_TYPE_RAW_NEC`; a captura foi feita e o atributo voltou para 0 automaticamente. O protocolo final foi confirmado restaurado como `NEC (0x1)`.
- O botao desconhecido produziu varios quadros RAW completos. As duracoes exibiram lider aproximado 9,10/4,44 ms, marcas curtas perto de 0,61 ms, espacos zero perto de 0,51 ms e espacos um perto de 1,64 ms, consistentes com NEC.
- A decodificacao LSB-first resultou no quadro `0xBC434040`: custom code `0x4040`, comando/scancode `0x43`, complemento `0xBC`. Como `0x43 XOR 0xBC = 0xFF`, a integridade NEC esta correta.
- No DTB original `docs/dtbs/aquario_original.dts`, mapa `cyxtech-remote-cs918`, custom code `0x4040`, a entrada e `0x43 -> 0x71`; `0x71` decimal 113 e Linux `KEY_MUTE`. Fontes publicas de firmware A95X/CS918 confirmam a mesma convencao `0x4040:0x43 = MUTE`.
- O arquivo original Aquario `remote_mouse2.tab` contem uma sobrescrita inconsistente `0x43 187`. No namespace Linux, 187 e `KEY_F17`; tanto `Vendor_0001_Product_0001.kl` quanto `Generic.kl` deixam `key 187 F17` comentado, portanto nenhum evento Android util e produzido. O valor Android `KEYCODE_APP_SWITCH=187` nao deve ser confundido com o codigo Linux de entrada 187.
- Conclusao provisoria daquela captura: o mapa generico CS918 identificava `0x43` como MUTE. O usuario esclareceu depois que o botao fisico e de opcoes/contexto; o mapa definitivo usa MENU. Nenhuma tabela ativa foi alterada nesta etapa.

### 2026-07-28 - v32 final: controle Aquario completo, mouse virtual e volume

- O controle fisico usa NEC custom code `0x4040`. POWER foi capturado em RAW learning como quadro `0xB24D4040`: scancode `0x4d`, complemento `0xb2`, portanto `0x4d -> KEY_POWER (116)`.
- Mapa definitivo dos 13 botoes: UP `0x0b -> 103`, DOWN `0x0e -> 108`, LEFT `0x10 -> 105`, RIGHT `0x11 -> 106`, OK `0x0d -> 97`, HOME `0x1a -> 102`, PLAY/PAUSE `0x45 -> 164`, BACK `0x42 -> 158`, VOL+ `0x18 -> 115`, VOL- `0x17 -> 114`, MOUSE `0x47 -> 388`, MENU/OPCOES `0x43 -> 139` e POWER `0x4d -> 116`.
- Correcao importante dos volumes: `meson-remote` imprime `scancode %d` em decimal. Assim, as mensagens `scancode 24/23 undefined` significavam hexadecimal `0x18/0x17`, e nao `0x24/0x23`. Depois da correcao, o sysfs mostrou `115 24` e `114 23`, e nao houve mais entrada indefinida no mapa.
- O usuario esclareceu que o botao `0x43` e destinado a menu de opcoes/contexto, favoritos ou recentes, conforme o sistema. Foi escolhido Linux `KEY_MENU (139)`, a funcao mais compativel com menu contextual do Android, em vez do `KEY_MUTE (113)` herdado do mapa generico CS918.
- O modo mouse usa `fn_key_scancode=0x47`, cursores `0x10/0x11/0x0b/0x0e` e OK `0x0d`. As capacidades `BTN_MOUSE`, `BTN_LEFT`, `BTN_RIGHT`, `BTN_MIDDLE`, `EV_REL`, `REL_X`, `REL_Y` e `REL_WHEEL`, removidas numa rodada anterior, foram restauradas em `remote_core.c`.
- Teste real aprovou o movimento: apos `0x47`, as setas geraram `EV_REL REL_X/REL_Y` com aceleracao. O clique ainda emitia `BTN_MOUSE`, que o Android nao tratava como clique primario; `remote_meson.c` foi corrigido para retornar `BTN_LEFT` quando OK e pressionado no modo mouse.
- A tabela final foi instalada em `/vendor/etc/remote.tab3`, root:root 0644, SHA256 `b371d5d3ddf15d55adbc406a810d8607408d040c289222ee1646046851e36a9c`. A arvore AOSP recebeu a mesma tabela em `vendor/aquario/stv3000/proprietary/etc/remote.tab3` e `stv3000-vendor.mk` passou a fornecer `remote.tab1..4` nos caminhos esperados.
- A causa da tabela vendor nao carregar no boot antigo eram os servicos `remotecfg1..4` do ramdisk apontando para caminhos inexistentes em `/system`. Na v32 eles apontam para `/vendor/bin/remotecfg -t /vendor/etc/remote.tab1..4`; a mesma correcao foi aplicada em `infra/aidan/aosp9/device/aquario/stv3000/init.amlogic.rc`.
- O DTB final incorpora o mapa como `mapname="khadas-ir"`, nome necessario para este driver ler os seis parametros de mouse. DTS compilavel: `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v32/dtbs/gxl_p281_1g_aquario_ir_sd25_fb1080-v30.dts`; DTB 57.837 bytes, SHA256 `a2ca7f1b450691cfe7099052052789db08166872932845fdbfcbde7f26efb341`.
- Kernel recompilado no container `android9-aquario-builder:latest` com `-j16`: Linux 4.9.113 `#14`, `Image.gz` 8.501.971 bytes, SHA256 `3cf2a9367f563a94cea0b53b2c7e5ba52a02b8fca078629fb9049221f232d6d1`.
- Boot final: `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v32/bootimgs/boot-khadas-fresh-p281-wifi-ir-auto-hdmi-ssh-remote-final-v32.img`, 14.909.440 bytes, SHA256 `8e3fbbc74c34a1f76a2200a08658aea8e64c1d26219c52af93f4f9962486f9da`; sobra de 1.867.776 bytes na regiao raw de 16 MiB.
- Backup anterior preservado em `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v32/backups/boot-before-remote-v32-16m.img`, SHA256 `bbdd4160aa57432f1c167ab12f39bd1c88ba0a572c9d291d37b84e40350fe291`.
- Gravacao e readback do boot final foram identicos. Reboot automatico aprovado: `sys.boot_completed=1`, SSH retornou, kernel `#14`, mapa `khadas-ir` com 13 entradas, volume `23/24`, mouse com `REL_X/REL_Y/REL_WHEEL`, e hash lido de `/dev/block/boot` identico ao artefato.

### 2026-07-28 - validacao funcional final de volume, clique e MENU

- O volume foi confirmado sem depender da barra HDMI: `STREAM_MUSIC` para a rota ativa `speaker` estava em 12/15, os botoes produziram repetidamente `KEY_VOLUMEUP` e `KEY_VOLUMEDOWN`, e o indice final caiu para 9/15. O valor paralelo `40000000 (default): 15` e apenas outra rota, nao invalida a alteracao da rota ativa.
- O Android classificou `aml_keypad` como teclado e cursor, fontes `0x00002303`, display associado, coordenadas 1920x1080 e botao liberado. Em modo mouse, setas geraram `REL_X/REL_Y` e OK gerou codigo Linux `0x110`, exibido pelo `getevent` como `BTN_MOUSE`; `BTN_MOUSE` e `BTN_LEFT` sao aliases do mesmo codigo, portanto e clique primario.
- O clique foi aprovado de ponta a ponta: primeiro abriu `org.cyanogenmod.appdrawer/.AppDrawerActivity` em 671 ms; depois um clique sobre um item abriu `com.anker.fileexplorer/.MainActivity` em 1.083 ms. Assim, a falha percebida era atraso visual/composicao ou estado normal/mouse, nao perda do clique.
- A lentidao visual e mensuravel: o File Explorer teve 4 de 15 frames janky (26,67%), percentil 90/95/99 em 200 ms. O pipeline HDMI/compositor pode atrasar ou esconder a resposta embora a atividade ja tenha sido iniciada.
- O botao especial `0x43` foi finalmente testado isoladamente e produziu repetidamente `KEY_MENU` down/up. O WindowManager recebeu `keyCode=82` em press/release. Aplicativos sem menu contextual para KEYCODE_MENU podem nao exibir nada; receptor, kernel, keylayout e framework receberam corretamente o botao.
### 2026-07-28 - v33: 1080p60 desde o HWC e diagnostico da composicao lenta

- O clique em Configuracoes nao estava perdido: `com.android.tv.settings/.MainSettings` era retomada e focada em cerca de 1,0 s, sem ANR, mas a TV continuava mostrando launcher + camada de dim. O WindowManager chegou a manter o launcher como `mObscuringWindow` em testes anteriores.
- O gargalo comprovado e grafico. SurfaceFlinger repete `failed to dup EGL native fence sync: 0x3000` e `syncForReleaseLocked: failed to flush RenderEngine`; Settings mediu 18/25 frames janky (72%) no teste anterior e 19/23 (82,61%) apos boot v33, com p95 entre 200 e 450 ms. CPU, temperatura, RAM e swap estavam normais e nao houve ANR.
- A saida antiga `2160p30hz` limitava toda a interface a 30 Hz. A v33 passou a preferir `1080p60hz` e, quando a EDID inicialmente seleciona 4K, troca para 1080p60 antes de iniciar o HWC. As tres escalas de animacao foram zeradas.
- Boot v33: `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v33/bootimgs/boot-khadas-fresh-p281-wifi-ir-1080p60-noanim-ssh-v33.img`, 14.909.440 bytes, SHA256 `9350259984850da8c3130acf0e850aecc65cd9c4eb8f7f71865ad55bd124d895`. Ramdisk SHA256 `924a04b18dbdbfda2d5d16bfa7a7f3634d7cdd9fdbd1a4dff6eff590156bf3`.
- Backup dos 16 MiB anteriores: `work/teste-khadas-fresh-20260728-wifi-ir-auto-hdmi-ssh-v33/backups/boot-before-v33-16m.img`, SHA256 `34dad067757726a1d7a4e89359f01549b73f30c727949cd25b431cf52b5696e7`.
- Gravacao e readback da v33 foram identicos. Boot limpo confirmou kernel 4.9.113 #14, HDMI e display logico 1920x1080 a 60 Hz, periodo SF 16.666.666 ns, animacoes 0, mapa IR final preservado e buffer de crash vazio.
- A mudanca removeu a tela anterior como `mObscuringWindow` em uma abertura controlada, mas nao eliminou o esmaecimento relatado pelo usuario. Portanto 1080p60/no-animation e uma melhoria valida, nao a correcao raiz dos fences.
- O SD `SC32G` tambem agrava abertura de apps: numa navegacao curta acumulou aproximadamente 12 MiB de leitura e 4,8 s de tempo de I/O, sem major faults ou swap-in. Em idle, CPU ficou 381% ociosa de 400% e `MemAvailable` em aproximadamente 441 MiB.
- GPU identificada como Mali-450 MP, EGL r8p0 (`1.4 Linux-r8p0-01rel0-4c24f21`), tres PP ativos, clock dinamico de 285 a 666 MHz. Forcar 666 MHz nao resolveu a tela de Settings; o problema ocorre no sincronismo/liberacao de buffers, nao apenas em potencia de shader.

### 2026-07-28 - controle em modo mouse e teste Mali r7p0 com DMA fences

- A falta de navegacao por setas observada pelo usuario coincidiu com o kernel ter registrado `switch to mouse mode` sem registro posterior de retorno ao teclado. Nesse estado as setas viram `REL_X/REL_Y`; e necessario apertar MOUSE novamente para voltar ao DPAD. O keylayout continua correto: 103/108/105/106 -> DPAD_UP/DOWN/LEFT/RIGHT e 97 -> DPAD_CENTER.
- O modulo ativo antes do teste era Utgard r6p1 AArch64, SHA256 `00ec929c1d8e8b79fadf58be6f3aa123587653521cda3c1670e01134202e9ed5`, enquanto a biblioteca userspace era r8p0, SHA256 `d48a0b038df82ccd18e830bb7bcd1a3c2af7857210d8322d44428d4f033e7c8e`. O build info do modulo r6p1 mostrava `USING_DMA_BUF_FENCE` vazio.
- Foi compilado no container `android9-aquario-builder:latest`, com `-j16`, o Utgard r7p0 contra o mesmo kernel output #14, usando `USING_DMA_BUF_FENCE=1`, `USING_GPU_UTILIZATION=1`, `USING_DVFS=0` e plataforma `meson_bu`.
- Artefato: `work/build-mali-r7p0-fence-khadas-4.9-20260728-v2/mali-r7p0-fence-stripped.ko`, AArch64, `vermagic=4.9.y SMP preempt mod_unload modversions aarch64`, versao `r7p0-00rel0`, 473.320 bytes, SHA256 `6c33b7285289051cac58f8ef60cf746ca98832dc991dd912feeba5a12977df1f`. O modulo inclui `mali_dma_fence.o` e os simbolos `mali_dma_fence_*`.
- Backups dos arquivos funcionais pre-teste: `work/mali-r7p0-fence-test-v34/backups/mali-r6p1-current.ko` e `libGLES_mali-r8p0-current.so`, com os mesmos hashes acima.
- Primeiro teste instalou modulo r7p0 + `libGLES_mali` r7p0 original Aquario (SHA256 `4c5321e56cf901fe603a10de4829acd03640f9c2f588d0b46c2c45e7a44adf08`). O modulo carregou e criou Mali normalmente, mas esta biblioteca nao e carregavel pela userspace Aidan: SurfaceFlinger aborta em loop com `couldn't find an OpenGL ES implementation`; Android/SSH nao concluem.
- Proximo teste correto: com o cartao no PC, restaurar somente a biblioteca r8p0 e manter o novo modulo r7p0-fence. Se EGL iniciar, medir se desaparecem `failed to dup EGL native fence` e o esmaecimento. Se nao iniciar ou os erros persistirem, restaurar tambem o modulo r6p1 funcional.

### 2026-07-28 - cartao preparado para teste r7p0-fence + userspace r8p0

- Cartao confirmado em `/dev/sdg`, 31.914.983.424 bytes, modelo `SC32G` no aparelho e leitor USB Generic no PC. Vendor acessada no offset `0x5d600000` (1.566.572.544), filesystem ext4 UUID `bcd49384-72e5-4251-8473-e65db406d601`, limite util 188.743.680 bytes.
- A retirada com o Android ligado deixou somente o contador de blocos livres desatualizado. `e2fsck -fy` corrigiu 8990 para 9030; nao havia erro de inode, diretorio ou conectividade.
- Antes da troca direta, o cartao confirmou exatamente o estado do teste falho: modulo r7p0-fence SHA256 `6c33b7285289051cac58f8ef60cf746ca98832dc991dd912feeba5a12977df1f` e biblioteca r7p0 SHA256 `4c5321e56cf901fe603a10de4829acd03640f9c2f588d0b46c2c45e7a44adf08`.
- Foi restaurada somente `/vendor/lib/egl/libGLES_mali.so` r8p0, SHA256 `d48a0b038df82ccd18e830bb7bcd1a3c2af7857210d8322d44428d4f033e7c8e`, root:root 0644. `/vendor/lib/modules/mali.ko` permaneceu no candidato r7p0-fence.
- Apos `sync`, desmontagem e novo `e2fsck -fn`, vendor passou sem erros: 987/46080 arquivos e 37066/46080 blocos usados. O loop foi removido e o cartao ficou pronto para remocao.
- Proximo boot deve responder duas perguntas: (1) r7p0 kernel API 900 e compativel com a `libMali` r8p0; (2) `mali_dma_fence` elimina ou reduz `failed to dup EGL native fence`/`failed to flush RenderEngine`. Se SurfaceFlinger nao subir, restaurar o modulo r6p1 salvo; se subir, medir Settings e launcher antes de tornar o modulo permanente na arvore AOSP/vendor.

### 2026-07-28 - rescue v35 e U-Boot v36 com politica eMMC/RESET/TFTP

- O novo eMMC soldado foi identificado como Samsung MAG4F, 14,9 GiB, barramento de 8 bits, MMC 4.41 e indicadores de vida A/B em zero. No U-Boot ele e `mmc 1`; no Linux, `/dev/mmcblk0`. O SD e `mmc 0` no U-Boot e `/dev/mmcblk1` no Linux. O eMMC ainda nao recebeu nenhuma gravacao.
- Foi criado `scripts/build_aquario_uboot_recovery.sh` e `scripts/patch_uboot_env_fixed.py` ganhou `--new-name`. O BL33 v36 implementa: boot normal tenta eMMC; GPIOAO_2/RESET ativo tenta SD; falha de qualquer ramo tenta o initramfs por TFTP. `upgrade_key=true` neutraliza o antigo updater associado ao RESET.
- Logica compilada: `aquario_boot=if gpio input GPIOAO_2;then run aquario_sd;run aquario_tftp;else run aquario_emmc;run aquario_tftp;fi`. O GPIO solto foi observado como valor 1, cujo retorno do comando leva ao ramo `else`/eMMC. SD e eMMC leem a boot image raw em `0x2ae000`, contagem `0x8000` setores.
- Rede de recovery: aparelho `192.168.1.139`, gateway/TFTP aparente `192.168.1.2`, com encaminhamento para o servidor real `192.168.1.10`; arquivo `aquario-rescue-initramfs-v35.img`.
- Bootloader v36: `work/uboot-recovery-v36-20260728/bootloader-recovery-v36-4m.bin`, SHA256 `ab36d9967d2519366195be10b3b05db94cfddfb77655b168c174b6cd16fe5663`. BL33 raw SHA256 `69f2d4744dcf5be8d65c968bfba35bc85b6b7a892ce1a52167085640034abd87`. Reextracao confirmou BL33 byte a byte; BL2/FIP/BL30/BL31 foram preservados.
- Backups anteriores: `work/uboot-recovery-v36-20260728/backups/bootloader-before-v36-4m.bin`, SHA256 `4e410ab037633c5fb092c03593fc388f73a3e8edb02e4c64542691e4dafdf44a`; `env-before-v36-8m.bin`, SHA256 `29b30e582b05081cdaad363698f78d43c12c7baf9f0b7b66458327d459af6b69`.
- O bootloader v36 foi gravado no SD e o readback de 4 MiB foi identico. O ambiente de 64 KiB foi gravado a partir de `env-recovery-v36-64k.bin`, SHA256 `ef2db6bf734c32bb7b36c082331b32319c5108e5f298f7d19cedd6afccfd2078`, tambem com readback identico. A configuracao reproduzivel esta em `configs/aquario-uboot-recovery-v36.env`.
- O U-Boot ainda informa `Using default environment` porque procura o env no eMMC antes de estabelecer a MPT do SD. Isto nao impede o recovery: os defaults compilados ja contem a politica. Depois da clonagem para eMMC, o env persistente deve ficar acessivel no dispositivo normal.
- Rescue v35: `work/aquario-rescue-initramfs-v35/aquario-rescue-initramfs-v35.img`, SHA256 `2cfaffeb5f793f17d8c4d925c278096e7625b206e03fe898ec6406dd7b58eb47`. Inclui kernel 4.9.113 #14, DTB Aquario, BusyBox AArch64 estatico, Dropbear estatico, chave SSH do PC, shell TTL e IP fixo. O artefato servido pelo container TFTP teve hash identico.
- O ramo normal foi validado parcialmente de ponta a ponta: GPIOAO_2 solto imprimiu valor 1, tentou a imagem invalida do eMMC e caiu no TFTP; o rescue iniciou em cerca de 10 s e aceitou SSH root via NAT em `192.168.1.254:2223`.
- O RESET fisico ainda NAO foi pressionado nem validado. Nao registrar o ramo RESET como aprovado ate observar o GPIO e o boot correspondente durante um ciclo fisico.

### 2026-07-28 - primeiro teste manual de `aquario_sd` com o novo eMMC presente

- No prompt `A95X#`, `run aquario_sd` leu com sucesso a boot image Android do SD e iniciou o kernel 4.9.113 #14. O kernel chegou ao first-stage init, portanto a funcao e o offset raw do boot estao corretos.
- Este ciclo NAO completou Android e nao e aprovacao do ramo SD: o first-stage init aguardou `odm, product, system, vendor`; o controlador MMC acumulou timeouts/CRC, terminou com `sd: error -110 whilst initialising SD card` e nao criou as particoes necessarias. O SSH Android nao apareceu.
- O mesmo boot tambem registrou timeouts do eMMC durante a sondagem. A falha atual e inicializacao/comunicacao dos barramentos MMC apos a entrada do kernel, nao leitura da boot image pelo U-Boot.
- O Android ficou preso antes de oferecer SSH. Proximo passo: ciclo de energia sem RESET, interromper o autoboot, repetir o ramo SD em estado eletrico limpo e comparar a enumeracao MMC. Somente depois de um boot SD completo deve ser feito o primeiro teste fisico, mantendo RESET pressionado desde a energizacao e observando o ramo escolhido.

### 2026-07-28 - validacao fisica do RESET e estado do novo eMMC

- A repeticao limpa de `run aquario_sd` enumerou o SD como `/dev/mmcblk1`, montou as particoes Android e concluiu com `sys.boot_completed=1`, kernel 4.9.113. O ramo SD manual esta aprovado; o primeiro ciclo com timeouts foi transitorio.
- O teste fisico foi executado mantendo RESET pressionado durante `reset` do U-Boot. O log mostrou `gpio: pin GPIOAO_2 (gpio 102) value is 0`, selecionou `mmc0`, leu 32768 blocos a partir de `0x2ae000` e iniciou o kernel Android 4.9.113 #14. O gatilho RESET -> SD esta aprovado.
- O bootloader v36 continua gravado somente no SD. A copia de 4 MiB foi publicada no TFTP como `aquario-uboot-recovery-v36-4m.bin`, 4.194.304 bytes, e o arquivo recebido no U-Boot teve CRC32 `76aaa720`.
- A gravacao no eMMC NAO foi feita: em todos os ciclos posteriores, `mmc dev 1` falhou silenciosamente e `mmc info` permaneceu no SD `SC32G`. O U-Boot inicia com `MMC init failed`; executar `mmc write` nesse estado sobrescreveria o SD, portanto a escrita foi corretamente bloqueada.
- O rescue 4.9 v35 tambem passou a mostrar apenas `/dev/mmcblk1`. O host `d0074000.emmc` existe, mas registra `no support for card's volts` e `emmc: error -22 whilst initialising MMC card`. Unbind/bind do driver antigo nao recuperou o dispositivo e o rebind encontrou estado sysfs residual; nenhuma escrita ocorreu.
- O Samsung MAG4F de 14,9 GiB havia sido identificado de forma completa em uma sessao anterior, logo o chip chegou a responder. A ausencia consistente atual em U-Boot, kernel 4.9 e kernel 6.12 indica problema fisico/intermitente de alimentacao, reset, clock, CMD ou dados, e nao tabela de particoes.

### 2026-07-28 - OpenWrt/LEDE 24.10.5 initramfs TFTP v37

- Fonte localizada: `infra/aidan/data/openwrt_lede_amlogic_s905w_k6.12.94_2026.07.01.img.gz`, SHA256 `9c3a088044552d12f56d915ca70c7bf67154f79901588bc890423f5c603f3499`. Imagem descomprimida de 1.749.024.768 bytes, com BOOT FAT de 383 MiB e ROOTFS Linux de 1,3 GiB.
- Identidade do rootfs: OpenWrt 24.10.5 `r0-771acca0`, target `armsr/armv8`, AArch64, source LEDE. BOOT contem kernel 6.12.94-ophub, `uInitrd` Debian auxiliar e DTB `meson-gxl-s905w-p281.dtb`.
- O `uInitrd` original nao e um OpenWrt independente: e initramfs Debian de cerca de 17 MiB que procura o rootfs Btrfs no disco. Foi criado `scripts/build_aquario_openwrt_tftp_initramfs.sh` para empacotar o rootfs OpenWrt dentro de um initramfs TFTP reproduzivel.
- Overlay em `rescue/openwrt-initramfs-overlay`: Ethernet/bridge LAN fixa em `192.168.1.139/24`, gateway e DNS `192.168.1.2`, hostname `aquario-openwrt-rescue`, Dropbear porta 22 sem senha e chave Ed25519 deste PC, mais UCI default equivalente.
- A imagem armsr generica continha modulos, firmwares, bootloaders e servidores para muitas placas. Duas versoes iniciais (95 MiB e 74 MiB comprimidas) falharam no unpack com `write error -28` por pressao de RAM. O builder passou a excluir modulos externos, firmwares de placas, bootloaders genéricos, Python, Perl, Git, Xray e FRP, preservando OpenWrt/UCI/LuCI/Dropbear e ferramentas de armazenamento.
- Artefatos reduzidos finais em `work/openwrt-tftp-initramfs-v37/output`: kernel `aquario-openwrt-rescue-v37-Image`, 41.837.056 bytes, SHA256 `eb4fa8bb1487cae27735736629dd91fec8281bbb3248481de9ff6fad4946bfa9`; initramfs raw XZ SHA256 `f84c0b718cdd6fa3da56cb5c584b718455e544c0643f6723b73f09835dc9f825`; `uInitrd`, 16.075.516 bytes, SHA256 `e8504191d51da3ffbacb0d7382de20fbc7483898966adf3f5de4d4d50682cd4a`; DTB P281, 41.027 bytes, SHA256 `f3849d01e23b5b63b5e0b05f25abd12ece45678901e6bc94724da1b71dd180bb`.
- O kernel 6.12.94 bootou manualmente por `booti`, detectou HDMI, Ethernet, SD e SDIO. Para o eMMC registrou `mmc2: no support for card's volts`, erro `-22`, `Card stuck being busy` e `Failed to initialize a non-removable card`, confirmando ausencia de resposta tambem no driver mainline.
- O initramfs final reduzido foi publicado no TFTP, mas ainda nao foi bootado: o ultimo teste usou a versao intermediaria de 74 MiB e terminou em panic por ENOSPC. Depois disso o adaptador `/dev/ttyUSB0` desapareceu e o broker encerrou. Proximo passo: reconectar TTL, iniciar broker, bootar o `uInitrd` final de 15,3 MiB e validar console, rede, Dropbear e LuCI.

### 2026-07-28 - memoria identificada pelo usuario como NAND aquece e nao foi detectada

- Com a nova memoria conectada, o U-Boot executou o driver de NAND raw (`Nand PHY Ver:1.01.001.0006`), mas recebeu `reset failed`, ID `fffffffe`, `chip detect failed` e `nandphy_init failed ret=0xfffffff1`. Portanto, a NAND raw nao foi detectada.
- Nesse mesmo ciclo, `mmc 1` voltou a responder como `PART_TYPE_DOS`. Isso e uma interface MMC separada e nao comprova que a memoria nova seja NAND raw; pode ser resposta de outro componente MMC/eMMC ou identificacao incorreta do encapsulamento pelo usuario.
- A memoria aqueceu muito nas duas orientacoes em que foi instalada. Nao energizar novamente: isso indica pinagem/encapsulamento incompativel, curto em VCC/VCCQ, orientacao incorreta ou componente ja danificado. A inversao tambem pode ter danificado o chip e/ou a placa.
- Antes de qualquer novo teste energizado, obter a marcacao completa do componente e o datasheet do fabricante, conferir tipo (eMMC ou NAND raw), mapa de esferas, orientacao do pino A1, encapsulamento, VCC/VCCQ e compatibilidade de ID/geometria/ECC com o controlador Amlogic. Fazer medicoes de resistencia para GND somente com a placa desligada e a memoria removida.
- O nome `MAG4F` observado anteriormente veio do campo de produto do CID MMC e nao determina sozinho o part number completo. Ele confirma uma eMMC Samsung de aproximadamente 16 GB/MCC 4.41, mas nao autoriza assumir que qualquer chip marcado como NAND ou qualquer eMMC fisicamente parecida use o mesmo footprint.
- Candidatos de pesquisa da geracao Samsung 169-FBGA incluem `KLMAG4FE3B-A001`, `KLMAG4FEJA-A001` e `KLMAG2GE4A-A001`; nenhum deve ser soldado antes de comparar o codigo completo do componente original, dimensoes/pitch, mapa de esferas e alimentacoes. Familias Samsung eMMC 5.1 atuais costumam usar 153-FBGA de 11,5 x 13 mm e nao sao substitutas fisicas automaticas para 169-FBGA.
- Nova observacao pelo TTL confirmou a mesma falha em varios ciclos consecutivos: `reset failed`, `get_chip_type ... fffffffe`, `chip detect failed` e `nandphy_init failed ret=0xfffffff1`. Nao houve identificacao da NAND. O dispositivo de 29,7 GiB enumerado em seguida como `SC32G`, `PART_TYPE_DOS`, e exclusivamente o cartao SD no controlador MMC.

### 2026-07-29 - estado do TTL apos reconexao

- O adaptador TTL reapareceu como `/dev/ttyUSB1`, CH341/USB UART-LPT `1a86:5523`, link estavel `/dev/serial/by-id/usb-1a86_USB_UART-LPT-if00-port0`. `/dev/ttyACM0` e um dispositivo separado `Temp-DISP`, nao o TTL da placa.
- O broker antigo ainda apontava para `/dev/ttyUSB0`; foi substituido pelo container `serial_ttyUSB1`, porta local 31337, 115200 baud e log `recovery-lab/logs/serial_ttyUSB1.log`.
- O TTL ainda nao esta funcional: Enter e Ctrl+C retornaram byte por byte no RX, mas sem texto ou prompt novo do U-Boot; durante tres segundos nao houve nenhum byte espontaneo. O comportamento indica loopback/curto entre TX e RX, conexao incorreta ou placa sem transmitir. Nao executar comandos ate corrigir a ligacao fisica e obter novamente `A95X#`.
- O SSH externo `192.168.1.254:2223` expirou e o acesso direto `192.168.1.139:22` retornou sem rota. Auditoria read-only pelo container `invade` mostrou `ether8 status: no-link` e nenhuma entrada ARP para `192.168.1.139`; a rota conectada da tabela `mr80x-recovery` existe, mas esta inativa porque a interface fisica esta sem link. O SSH nao pode retornar ate a box/PHY Ethernet estabelecer link na ether8.
- Diagnostico controlado do TTL confirmou loopback fisico: com o broker parado, em 115200 foram transmitidos `7e55` e recebidos exatamente `7e55`; em 9600 foram transmitidos `7e4c` e recebidos exatamente `7e4c`. Um U-Boot fixo em 115200 nao poderia responder corretamente nas duas taxas. TX e RX estao unidos na fiacao/placa, ha jumper de loopback no adaptador, ou o adaptador esta defeituoso. O broker foi restaurado em `/dev/ttyUSB0`, 115200, porta 31337. Para isolar, desligar a placa, desconectar TX/RX dela e repetir o teste com o adaptador livre; nunca conectar VCC do TTL.
- A fiacao TTL foi corrigida pelo usuario e o prompt real `A95X#` voltou. Um reset novo confirmou a NAND raw ausente: a Boot ROM mostrou `EMMC:800;NAND:81;SD:0`, e o U-Boot registrou `Nand PHY`, `reset failed`, ID `fffffffe`, `chip detect failed` e `nandphy_init failed 0xfffffff1`.
- O rescue Linux/Android kernel 4.9 tambem nao encontrou NAND: `/proc/mtd` contem somente o cabecalho, `/sys/class/mtd` esta vazio, nao existe `/dev/mtd*`, e `/proc/partitions` mostra apenas o SD `/dev/mmcblk1`. Nao houve probe NAND no dmesg nem no DTB ativo. O unico evento MTD foi `mtdoops` reclamando da falta de dispositivo configurado. Assim, Android userspace nao tem dispositivo NAND para exibir; adicionar driver/DT nao corrige a ausencia de resposta eletrica ja comprovada pelo U-Boot.

### 2026-07-29 - imagem Android 9 v38 para eMMC de 8 GB e falha de gravacao do dispositivo

- Foi preparada `work/aquario-emmc-8g-android9-v38/aquario-android9-emmc-8g-swap2g-v38.img`, com exatamente 7.752.122.368 bytes e SHA256 `c7e26c67684b7ca70ba7b2d2239e211cefd81f6dde99c6648f095a693441831a`. A imagem contem Android 9, boot/kernel v38, vendor reconstruida estavel, system-full-v10, data ext4 fresca e 2 GiB de swap fisico. O zram continua habilitado e deve permanecer como swap prioritario; o swap em flash e mais lento e aumenta desgaste.
- O bootloader e o ambiente sao o U-Boot recovery v36. Politica configurada: boot normal tenta Android no eMMC; RESET/GPIOAO_2 pressionado tenta Android no SD; falha em qualquer ramo tenta rescue por TFTP. O bootloader de 4 MiB tem SHA256 `ab36d9967d2519366195be10b3b05db94cfddfb77655b168c174b6cd16fe5663`.
- Layout Amlogic EPT principal: boot em 1372 MiB/16 MiB, vendor em 1494 MiB/512 MiB, system em 2150 MiB/1856 MiB, data em 4150 MiB/1186 MiB e swap em 5344 MiB/2048 MiB. O swap possui label `aquario-swap`, UUID `7f35232c-87bb-4570-86b4-6b0c5dd8f21b`, e foi adicionado ao `fstab` como `/dev/block/swap none swap defaults wait,nofail`.
- A imagem foi validada offline: EPT/DTB coerentes, componentes comparados exatamente, vendor/system/data passaram `e2fsck -fn` e a assinatura Linux swap v1 foi encontrada no offset correto. Boot v38 SHA256 `cc5f0add615b6116a42803fe8fc3cb1c35bdff9599f77d2a37764c18627430b4`; vendor v38 SHA256 `3044fe0abc058431300689ab7db6d193a54325ec7818328c8d0389707a737666`; system-full-v10 SHA256 `471122d7cf0eff505a58c6e9abc04949a580308c3f24f5e3219264cdd2be732a`.
- O dispositivo apresentado no PC foi `/dev/sdh`, by-id `usb-Multiple_Card_Reader_058F63666438-0:0`, leitor Alcor `058f:6366`, modelo `Card Reader`, 7.752.122.368 bytes, removivel, `RO=0` e sem montagem. Uma leitura sequencial anterior passou de 1 GB sem erro, mas o adaptador USB nao expoe `EXT_CSD`, portanto nao foi possivel consultar vida util/desgaste real do eMMC.
- Foi executado `dd` integral com `bs=4M oflag=direct conv=fsync`: 7.752.122.368 bytes reportados como escritos em 410,6 s, sem erro de I/O. A leitura integral posterior tambem terminou sem erro, mas produziu SHA256 `55ec6af7bbe8927c6c48f1733e3797968f245a27583bfc17d583d2b152baa50b`, diferente da imagem.
- A divergencia comeca no byte 0. Em vez do U-Boot, o dispositivo retorna continuamente o padrao `02 00 03 00`; os primeiros 4 MiB tem SHA256 `8005026f2a2453d0f64c7c8062583f08e3b01a212f0f0936799cb5dba15bf047`. Tres leituras deram o mesmo resultado. Regravar isoladamente os primeiros 4 MiB com `oflag=direct,conv=fsync` nao alterou nenhum byte. Reiniciar fisicamente o leitor com `usbreset 058f:6366` tambem manteve exatamente o mesmo padrao.
- Conclusao: apesar de anunciar `RO=0` e concluir comandos SCSI WRITE sem erro, esse conjunto leitor/adaptador/eMMC ignora as escritas. O eMMC NAO esta gravado e nao deve ser instalado esperando boot. Causas provaveis: adaptador/contato/pinagem defeituoso, leitor Alcor incompativel com o adaptador eMMC ou eMMC em modo somente leitura permanente por falha/desgaste. Proximo teste: usar outro leitor/adaptador eMMC confiavel (o leitor Genesys `05e3:0751` apareceu vazio no PC), gravar a mesma imagem e aceitar o chip somente se a leitura integral retornar exatamente SHA256 `c7e26c67684b7ca70ba7b2d2239e211cefd81f6dde99c6648f095a693441831a`.

### 2026-07-29 - segunda eMMC de 8 GB instavel no leitor e ausente na placa

- A segunda eMMC apareceu intermitentemente no leitor Alcor `/dev/sdh` como 15.269.888 setores de 512 bytes, 7.818.182.656 bytes (7,28 GiB), sem protecao de escrita. Segundos depois a capacidade caiu para zero. O kernel registrou repetidamente `Sense Key: Not Ready`, ASC/ASCQ proprietarios `ff/ff`, falhas READ(10) e `detected capacity change from 15269888 to 0`. Monitoramentos de 8, 12 e 20 segundos mostraram somente zero setores. Portanto, o contato/adaptador nao ficou estavel o suficiente para gravacao.
- Para esse tamanho exato, a variante pretendida com swap reduzido deve terminar em 7455 MiB, deixando 1 MiB de margem: data inicia em 4150 MiB, tamanho 2273 MiB; gap de 8 MiB; swap inicia em 6431 MiB, tamanho 1024 MiB. Isso oferece aproximadamente 2,22 GiB brutos em `data` e 1 GiB de swap.
- Com a eMMC instalada na box e o U-Boot interrompido pelo TTL, `mmc list` mostrou SDIO Port B=0 e Port C=1. `mmc dev 1` falhou em CMD8, CMD55 e CMD1 com `status=0x1ff2800`. `mmc info` permaneceu no SD de 29,7 GiB `SC32G`, provando que a nova eMMC nao foi inicializada pelo controlador Amlogic.
- Tentativa de iniciar `aquario-rescue-initramfs-v35.img` por TFTP, aparelho `192.168.1.139` e servidor aparente `192.168.1.2`, chegou a transferir parte do arquivo, mas a placa reiniciou durante a carga. Ciclos seguintes alternaram `card in`/`card out`, falharam novamente na eMMC e reiniciaram durante novo TFTP. O rescue Linux nao chegou a iniciar.
- Conclusao: nao existe atualmente um dispositivo eMMC acessivel para o U-Boot ou Linux gravar. A instabilidade tambem provoca resets durante TFTP. Antes de nova tentativa, revisar solda/contato, orientacao A1, VCC, VCCQ, GND, CLK, CMD e pelo menos DAT0, procurando curto ou queda de tensao. A imagem Android/TFTP nao pode corrigir ausencia eletrica de resposta ao CMD1.

### 2026-07-29 - eMMC detectada em ROM Mode, imagem v39 criada e escrita descartada pelo chip

- Apos novo ajuste fisico, o U-Boot passou a inicializar `mmc 1` repetidamente: SDIO Port C, MMC 4.41, 8 bits, 25 MHz e 7,2 GiB. O rescue v35 iniciou por TFTP e o Linux criou `/dev/mmcblk0` com exatamente 15.140.864 setores (7.752.122.368 bytes), alem de boot0/boot1 de 2 MiB e RPMB de 128 KiB.
- Foi criada `work/aquario-emmc-8g-android9-v39/aquario-android9-emmc-8g-swap1g-v39.img`, 7.752.122.368 bytes, SHA256 `0062b9ceb558beab3e9eb330c7e5e6f26289b0d9dc34268213f1f1b69f935033`. Ela preserva U-Boot recovery v36 e Android v38, usa data em 4150 MiB com 2210 MiB, gap de 8 MiB, swap em 6368 MiB com 1024 MiB e margem final de 1 MiB. O DTB reservado e o DTB embutido no boot foram atualizados para o novo layout.
- Componentes v39 validados offline: bootloader, env, boot, vendor, system pelo tamanho real de 1.000 MiB, data e swap compararam exatamente; data passou `e2fsck -fn`; gap e margem final sao zero. Data UUID `4dfc9e99-b59f-44f7-92ac-0797911e04c6`; swap label `aquario-swap`, UUID `80b41c0b-1c3e-4627-b22f-a08726943ecc`.
- A imagem inteira foi transmitida via SSH/NAT `192.168.1.254:2223` ao rescue e enviada a `/dev/mmcblk0`; `dd` reportou 7.752.122.368 bytes escritos e sincronizados em 354,6 s, sem erro. Entretanto, o SHA256 integral lido da eMMC permaneceu `55ec6af7bbe8927c6c48f1733e3797968f245a27583bfc17d583d2b152baa50b`, o mesmo conteudo observado no leitor defeituoso/anterior, em vez do hash v39.
- Teste isolado confirmou escrita descartada: os primeiros 4 KiB esperados tinham SHA256 `e83da90466b0ef6d06c4eab2cae92b45083939423474c73e4717b93e9549edcd`; apos WRITE+fsync, a leitura continuou com SHA256 `13ee9f795bf6ec170bf925cd7fb082f8bc78384c93a970cf4b949086f2a88193` e padrao fixo `02 00 03 00`. O kernel anuncia `ro=0` e `force_ro=0`, portanto o descarte ocorre dentro do dispositivo.
- Identificacao decisiva em `/sys/bus/mmc/devices/emmc:0001`: CID `65646f4d204d4f521290000007265800`, manfid `0x65`, OEM `0x646f`, nome `M MOR\x12`. Os bytes ASCII iniciais formam `edoM MOR`, que invertido le `ROM Mode`. Os campos enhanced tambem sao invalidos/underflow (`enhanced_area_offset=18446744073709551594`, `enhanced_area_size=4294967274`), `ffu_capable=0`, life_time `0x00 0x00` e pre_eol `00`.
- Conclusao: o componente esta em ROM/factory mode, e falso, ou seu controlador nao encontra NAND funcional. Ele emula uma eMMC de 8 GB, mas descarta todas as escritas. Nao ha correcao por U-Boot, TFTP, kernel ou formatacao; substituir por uma eMMC genuina e saudavel. Antes de aceitar o proximo chip, o nome/CID nao pode indicar `ROM Mode`, um WRITE de 4 KiB deve persistir e somente depois deve ser feita a gravacao integral.
- Teste independente pelo U-Boot eliminou a hipotese de driver Linux incorreto. Em `mmc 1`, 512 bytes de RAM foram preenchidos e conferidos como `5a a5 5a a5`; `mmc write 0x12000000 0 1` reportou `1 blocks written: OK`. Apos zerar outro buffer e executar `mmc read` do bloco 0, o conteudo voltou como `02 00 03 00`. `cmp.b` divergiu no primeiro byte (`0x5a != 0x02`). Assim, tanto U-Boot quanto kernel Linux e leitor USB observam o mesmo dispositivo que confirma WRITE mas nao persiste dados.

### 2026-07-29 - retorno ao Android no SD e avaliacao de filesystem

- O Android foi iniciado explicitamente pelo SD com `run aquario_sd`. O kernel encontrou `mmcblk1`/SC32G de 29,7 GiB e chegou ao shell Android, montando particoes e configurando HDMI em `1080p60hz`, mas sofreu uma sequencia longa de timeouts `CMD18` e retries de fase durante o first-stage mount. O driver acabou recuperando e o userspace prosseguiu.
- Esses timeouts ocorrem na camada de transporte MMC, antes de ext4/Btrfs/F2FS; trocar filesystem nao os corrige. O kernel #14 atual possui `CONFIG_EXT4_FS=y`, mas `CONFIG_BTRFS_FS` e `CONFIG_F2FS_FS` estao desativados.
- Para este Android 9/kernel 4.9, manter system/vendor em ext4 e a opcao mais compativel e leve. Btrfs exigiria recompilar kernel e adaptar fs_mgr/fstab/SELinux, usa mais RAM/metadata e COW pode piorar escrita aleatoria no SD. Se futuramente for desejado otimizar somente `data`, F2FS e o candidato mais apropriado para flash, apos habilitar kernel e suporte userspace; primeiro e necessario estabilizar o barramento SD.
- Causa da falta de navegacao DPAD no launcher confirmada na fonte ativa: `remote.tab3` define MOUSE em scancode `0x47`, setas `0x0b/0x0e/0x10/0x11` e OK `0x0d`; o keylayout mapeia corretamente Linux 103/108/105/106 para DPAD e 97 para DPAD_CENTER. Porem `remote_meson.c` alterna `ir_dev_mode` ao receber `0x47`; em MOUSE_MODE, `ir_report_rel()` consome as setas antes de `getkeycode()` e emite REL_X/REL_Y, enquanto OK vira BTN_LEFT. Assim o launcher nao recebe DPAD enquanto o modo mouse estiver ativo. Apertar MOUSE novamente retorna ao NORMAL_MODE. Separadamente, stalls CMD18 podem atrasar qualquer resposta da interface mesmo em modo normal.
- Reinicio manual correto concluido: a partir do rescue, reboot para U-Boot, aborto do fallback TFTP e `run aquario_sd`. Android no SD concluiu com `sys.boot_completed=1`, bootanim `stopped`/exit 1, hwcomposer, system_control e aquario.wifi-hal em `running`, HDMI `1080p60hz` e foco em `com.google.android.tvlauncher.MainActivity`. Foram contados 10 `req failed` do SD durante o boot, mas os retries recuperaram e o sistema permaneceu acessivel por SSH externo `192.168.1.254:2223`.

### 2026-07-29 - cartao de 30,95 GB no leitor do PC nao e legivel

- Um dispositivo removivel apareceu como `/dev/sdg`, Generic STORAGE DEVICE, 60.456.960 setores/30.953.963.520 bytes (28,8 GiB), sem particoes, filesystem ou montagem reconhecidos.
- Teste read-only de leitura sequencial direta, planejado para 1 GiB, nao conseguiu ler nenhum bloco: apos aproximadamente 30 s, `dd` terminou com `Input/output error`, 0 bytes copiados e 0 kB/s.
- O kernel registrou em varias LBAs `Sense Key: Medium Error` e `Add. Sense: Incompatible medium installed` para comandos READ(10). Portanto nao foi executado teste de escrita. Reencaixar cartao/adaptador ou testar outro leitor; no estado atual a velocidade util de leitura e zero e o dispositivo nao serve para o Android.

### 2026-07-29 - ausencia de PCIe no GXL/P281

- A arvore DTS usada pelo Aquario, `mesongxl.dtsi` + `gxl_p281_1g.dts` (S905W/GXL), nao possui node PCI/PCIe, `pci-controller` nem `device_type = "pci"`. Outras familias presentes na mesma fonte, como AXG, G12A/G12B, SM1 e TM2, possuem nodes PCIe, mostrando que a ausencia no GXL nao e apenas omissao da busca.
- O kernel compartilhado tem infraestrutura generica `CONFIG_PCI=y` e DesignWare PCIe compilada, mas isso nao cria um controlador inexistente no DT/SoC. Nesta box nao ha barramento PCI/PCIe utilizavel ou pads expostos. As expansoes praticas sao USB 2.0 e SDIO; o Wi-Fi SV6051P ja usa SDIO. SDIO nao e eletricamente compativel com PCIe.
- O usuario possui um modulo de armazenamento de 20 GB no formato Mini PCIe. E necessario identificar modelo/interface: muitos SSDs de 20 GB nesse formato sao mSATA, embora usem conector fisicamente semelhante ao Mini PCIe. Se for mSATA, pode ser usado com ponte ativa mSATA->USB; se for PCIe verdadeiro, adaptador passivo ou ligacao ao SDIO nao funciona e seria necessaria uma ponte PCIe->USB especifica. A box limita qualquer ponte ao USB 2.0 (480 Mb/s nominal). Estrategia possivel: manter apenas U-Boot/boot no SD e mover system/vendor/data para o SSD USB, adaptando boot e fstab.

### 2026-07-29 - launcher nao navega por causa da interface IR hibrida

- O Android iniciou normalmente, com TV Launcher em foco e InputDispatcher habilitado, nao congelado e sem fila pendente. A interface `/dev/input/event1` (`aml_keypad`) era classificada como teclado, DPAD e cursor ao mesmo tempo (`Sources 0x2303`) porque anunciava `EV_KEY`, `BTN_MOUSE`, `EV_REL`, `REL_X/Y/WHEEL` no mesmo `input_dev`.
- Injecao direta de Linux `KEY_LEFT` no event1 chegou ao WindowManager como Android `keyCode=21`, `scanCode=105`, mas o TV Launcher registrou `Unhandled key` e nao moveu o foco. Isso confirma que keymap e InputDispatcher funcionam; a origem hibrida do evento e o defeito estrutural.
- O utilitario Android `input` tambem esta quebrado nesta imagem: termina com status 134/SIGABRT em `app_process32`, precedido por `Could not reserve sentinel fault page`. Isso e separado do IR e impede usar `input keyevent` como teste.
- Correcao implementada na fonte ativa do kernel: `remote_dev` ganhou `mouse_input_device`; `aml_keypad` agora anuncia somente teclado/DPAD e o novo `aml_remote_mouse` anuncia exclusivamente REL_X/REL_Y/WHEEL e BTN_LEFT. Movimento e clique no MOUSE_MODE foram direcionados ao segundo dispositivo. Assim o botao mouse continua existindo sem contaminar a origem das setas.
- O driver remoto compilou sem erro. A tentativa adicional de `modules` parou apenas em warnings `maybe-uninitialized` antigos de `drivers/media/dvb-frontends/drxd_hard.c`; `Image.gz` foi compilado isoladamente com sucesso pelo container `android9-aquario-builder`, `-j16`, 8.501.910 bytes, SHA256 `cae0271467aaa5b06efbd55cbe20fa99a38b234e04fe61bcd2c2b4285997dbfd`.
- Boot v40 gerado preservando ramdisk v33, DTB v32 e cmdline validada: `work/teste-khadas-fresh-20260729-ir-split-v40/bootimgs/boot-khadas-fresh-p281-ir-split-mouse-v40.img`, 14.909.440 bytes, SHA256 `24c916ec66f8fa1fdb70d024028a8dc53d9eac9598a23bedbdc274b56ff0034e`.
- Pedido adicional: pre-instalar Chrome, YouTube, File Explorer e reprodutor MP4/AVI/MKV na imagem. O File Explorer ja esta instalado na imagem atual; ainda e necessario selecionar APKs Android 9/ARM32 compativeis e leves, validar navegacao por controle e integra-los de forma reproduzivel ao system/data.

### 2026-07-29 - U-Boot v41 inicia diretamente pelo SD e exibe logo Android

- Foi gerado `work/uboot-sd-logo-v41-20260729/bootloader-sd-logo-v41-4m.bin`, SHA256 `bf60e415390a713da70f53b4b3d72c85f41702b76f9f4eacd70dc4efe3113365`.
- O ambiente padrao executa `aquario_logo`, depois le o boot Android diretamente do SD (`mmc 0`, setor `0x2ae000`, `0x8000` setores) e so tenta TFTP se o `bootm` retornar. O caminho automatico nao consulta eMMC. TFTP usa servidor `192.168.1.2` e cliente `192.168.1.139`.
- O logo oficial Android, BMP 800x450 em fundo preto, foi gravado no setor `0x272000`: `work/uboot-sd-logo-v41-20260729/android-logo-raw-2m.bin`, SHA256 `1ad37b2da423fab24dd9daf19cb69ae7c07afc792a88074301effa58e2c21166`.
- U-Boot e logo foram verificados por readback completo. Reinicio automatico mostrou leitura do logo e do boot em `mmc0`, sem selecionar `mmc1` e sem entrar em TFTP, seguido pelo Android.
- A funcao de tres resets para TFTP ainda nao foi implementada; o fallback atual e falha de boot no SD seguida por TFTP.
- O segundo cartao no PC apareceu como `/dev/sdg`, 30.953.963.520 bytes, mas o leitor retornou `Medium Error`/`Incompatible medium installed` ate para leitura do setor zero. Nenhuma escrita foi feita nesse cartao; ele precisa ser reencaixado ou usado em outro leitor.

### 2026-07-29 - v42: foco do TV Launcher e saida segura do modo mouse

- Captura fisica confirmou que o receptor, kernel e keylayout entregam LEFT/RIGHT/UP/DOWN, DPAD_CENTER e BACK corretamente em `/dev/input/event1`. O Android traduz `97 -> DPAD_CENTER`, `103 -> DPAD_UP`, `105 -> DPAD_LEFT`, `106 -> DPAD_RIGHT` e `108 -> DPAD_DOWN`.
- A falha observada nao era perda das teclas: o log do launcher mostrou `Dropping event due to no window focus` e `Unhandled key`. Depois de relancar Home, uma injecao identica no mesmo `event1` foi aceita e a captura de tela confirmou foco azul em `App Drawer`.
- `remote_meson.c` agora faz Home ou Back restaurarem `NORMAL_MODE` quando o controle estiver em `MOUSE_MODE`; o botao Mouse continua alternando o apontador e OK continua sendo BTN_LEFT nesse modo.
- O servico `aquario.postboot`, disparado por `sys.boot_completed=1`, espera tres segundos e relanca `android.intent.category.HOME`, evitando que o launcher permaneça retomado sem possuir foco de entrada.
- Kernel compilado no container `android9-aquario-builder:latest`, `-j16`: `Image.gz` 8.502.226 bytes, SHA256 `3f673796fdc0dd54ebf7bcd26d762757ff209fca06aae52e84c769c35fae0e85`.
- Boot v42: `work/teste-khadas-fresh-20260729-ir-focus-v42/bootimgs/boot-khadas-fresh-p281-ir-focus-v42.img`, 14.891.008 bytes, SHA256 `893b20c0f31549c83c138c8cd1e358e11fb38dce5fd1bfba8020f9c2fa9c6a6a`.
- Backup dos 16 MiB anteriores: `work/teste-khadas-fresh-20260729-ir-focus-v42/boot-before-v42-16m.img`, SHA256 `22f6477894acfa8d36d51cf68317de08331d406377edf713c8b7b910aaf3b05f`.
- A imagem v42, preenchida ate 16 MiB, foi gravada no SD `mmcblk1`, setor `0x2ae000`. Hash local, arquivo preparado no aparelho e readback completo coincidiram: `30eefaeb0df80aba3c69741777a239b2eeb7e89e4c09600996c2fc2f8aaa8646`.
- Ideia solicitada para depois: indicador discreto proximo a engrenagem do Home com uso de CPU, RAM e GPU. Como Google TV Launcher e precompilado, preferir um overlay de sistema integrado visualmente, em vez de alterar diretamente o APK.
- Requisito visual pendente: o logo Android deve aparecer no U-Boot e permanecer continuamente visivel durante o carregamento do kernel, sem tela preta entre U-Boot, kernel e bootanimation. Implementar handoff do framebuffer/logo reservado da Amlogic e manter o OSD ate o primeiro frame do Android; nao basta apenas redesenhar o logo mais tarde no kernel.
- Validacao real do v42: Android iniciou com kernel `4.9.113 #16`, `sys.boot_completed=1`; apos os tres segundos, `mCurrentFocus` e `mFocusedApp` passaram para `com.google.android.tvlauncher/.MainActivity`. O controle fisico abriu `AppsViewActivity` e depois `com.anker.fileexplorer/.MainActivity`, comprovando DPAD e OK funcionais.
- A lentidao percebida restante e de apresentacao grafica, nao de entrada: SurfaceFlinger mostrou 95,7% do tempo na faixa de sete ou mais frames atrasados e logs anteriores continham `RenderEngine ... failed to flush`. GLES identifica `ARM, Mali-450 MP`, GPU em 666 MHz, refresh 60 Hz; no snapshot havia 433.880 kB de memoria disponivel e CPU majoritariamente ociosa, mas load average 6,96. Investigar HWC/composicao e processos iniciados em massa separadamente.

### 2026-07-30 - v43 falha por ABI e v44 corrige o foco visivel

- O controle e o InputDispatcher estavam corretos; a selecao mudava internamente, mas o quadro novo nao chegava ao HDMI. O erro raiz era repetido por todas as superficies: `failed to dup EGL native fence sync: 0x3000` seguido de `syncForReleaseLocked: failed to flush RenderEngine`.
- O conjunto grafico ativo e Mali-450: modulo Utgard r7p0 com DMA fences, SHA256 `6c33b7285289051cac58f8ef60cf746ca98832dc991dd912feeba5a12977df1f`, e `libGLES_mali.so` r8p0, SHA256 `d48a0b038df82ccd18e830bb7bcd1a3c2af7857210d8322d44428d4f033e7c8e`. Mesmo assim, a extensao `EGL_ANDROID_native_fence_sync` anunciada pela libMali nao funciona neste conjunto.
- A primeira tentativa v43 recompilou apenas `libgui.so` da arvore AOSP com uma propriedade para desativar native fences. O artefato SHA256 `5cb9a6c618aea50c751dcac725d65cdf26cdccd07b328e3a70f9df961e30e310` nao era ABI-compativel com os demais binarios Aidan e fez zygote/framework reiniciarem. Ele foi removido pelo rescue TFTP v35; `/system/lib/libgui.so` foi restaurado a partir de `/data/local/tmp/libgui-before-v43.so`, hash `56c40cbd8687782869ba3298b55481b9cf50203c9dc5dddcc7746649d85d4e17`.
- Durante a recuperacao havia dois shells lendo `ttyS0`, o console Android e BusyBox PID 3055, o que dividia caracteres. Reiniciar o broker serial com `--tx-byte-delay 0` permitiu enviar blocos inteiros; a recuperacao definitiva foi feita pelo U-Boot, TFTP `aquario-rescue-initramfs-v35.img`, montagem de `mmcblk1p18` e `mmcblk1p20`, copia e verificacao do hash.
- A v44 parte do binario Aidan exato e altera somente `SyncFeatures::useNativeFenceSync() const`, em VMA `0x5f5d0`: `ldrb r0,[r0]` virou `movs r0,#0`. Apenas o byte no offset de arquivo `0x585d1` mudou de `0x78` para `0x20`; tamanho e ABI foram preservados. Artefato `work/surfaceflinger-nofence-v44/libgui-aidan-native-fence-off-v44.so`, SHA256 `4503293e12c2f03fc031cc6f0893b8f613bca9118777acd1e5cc6fe5d1e48b73`.
- A v44 foi instalada em `/system/lib/libgui.so`, com backup `/data/local/tmp/libgui-before-v44.so`. O reboot direto pelo U-Boot v41/SD concluiu com kernel `4.9.113 #16`, `sys.boot_completed=1`, SSH ativo e foco real no TV Launcher. Depois do boot, as contagens de `failed to dup EGL native fence` e `failed to flush RenderEngine` foram ambas zero.
- A placa de captura HDMI do PC e `/dev/video0`, MJPEG/YUYV ate 1920x1080. O aplicativo `/usr/bin/pinhole` normalmente mantem o dispositivo aberto. Captura real confirmou o foco branco no Gboard e, depois, foco visivel no Home sobre o File Explorer. Fechar/reabrir a captura gera hotplug HDMI: o Android seleciona brevemente 2160p30 e o postboot retorna para 1080p60; aguardar estabilizacao antes de confiar no primeiro quadro.
- Nao houve eventos IR fantasmas em 8 segundos de `getevent`; InputDispatcher ficou sem evento pendente e fila de entrada vazia. O salto visual `v` para Backspace ocorreu no Gboard comum `com.google.android.inputmethod.latin`, que nao e um teclado de TV e tem navegacao DPAD geometrica ruim. Tratar o teclado separadamente, preferencialmente instalando um IME Android TV/Leanback; nao reverter a v44 por esse comportamento.
- A fonte Android agora le `ro.aquario.disable_native_fence_sync` alem da propriedade persistente, e o produto `aquario_stv3000` define a propriedade read-only como `1`. Assim, uma futura compilacao coerente do system aplica a mesma correcao sem patch binario. O ramdisk base v33 usado pelas imagens recentes foi ajustado para escalas de animacao `0.5`, `0.5` e `1.0`.

### 2026-07-30 - Internet da VRF Aquario sem quebrar SSH/TFTP

- O MikroTik `192.168.1.254`, RouterOS 7.23.1, foi analisado e alterado pelo container do projeto `invade`. Antes das mudancas foi salvo inventario em `/media/dados_2tb/opw/invade/data/raw/20260730_030454`.
- Foram preservados a VRF `mr80x-recovery` na `ether8`, o gateway `192.168.1.2/24`, o SSH externo `192.168.1.254:2223 -> 192.168.1.139:2222` e o redirecionamento TFTP `192.168.1.2:69 -> 192.168.1.10:69`.
- A VRF recebeu rota default ativa por `192.168.1.1@main`, classificacao propria `aquario-internet`, retorno marcado para `mr80x-recovery`, source NAT para `192.168.1.254` e uma regra anterior ao FastTrack. O classificador exige origem `.139`, entrada `ether8` e destino nao local, portanto nao captura TFTP/SSH destinados ao gateway `.2`.
- Foi criado DHCP dedicado na `ether8`, pool de um unico endereco `.139`, lease estatico para MAC `62:2C:D3:AC:57:A9`, gateway `.2` e DNS `1.1.1.1,1.0.0.1`. A rede DHCP especifica e `192.168.1.139/32`, evitando ambiguidade com a LAN sobreposta.
- Validacao no Android: endereco `.139/32`, rota `.2/32`, default via `.2`, DNS Cloudflare, ping IP e DNS funcionando e `ConnectivityService` em `VALIDATED`, score 70. SSH continuou acessivel. O TFTP nao foi executado pelo Android porque seu BusyBox nao possui o applet, mas as regras anteriores foram preservadas e o novo classificador exclui explicitamente destinos locais como `.2`.

### 2026-07-30 - estado inicial de WPA3 e aplicativos

- O `/vendor/bin/hw/wpa_supplicant` instalado contem as capacidades/textos `SAE`, `FT-SAE`, `WPA3` e `ieee80211w`. Na fonte AOSP, `external/wpa_supplicant_8/wpa_supplicant/Android.mk` forca `CONFIG_SAE=y` e `android.config` habilita `CONFIG_IEEE80211W=y`; assim supplicant e PMF, requisitos centrais de WPA3-Personal, ja estao compilados.
- Ainda e necessario confirmar se o framework Android 9 consegue cadastrar redes SAE e se o driver SV6051P conclui autenticacao com PMF. Android 9 antecede o suporte oficial completo de WPA3 na interface do sistema; presenca de strings no supplicant, isoladamente, nao comprova conexao funcional.
- A particao `/system` instalada tem aproximadamente 983 MiB, 842 MiB usados e apenas 141 MiB livres. Chrome, YouTube TV e um reprodutor completo provavelmente excedem essa folga juntos. A particao fisica reservada ao system e maior que o filesystem atual, portanto a estrategia preferida e ampliar a imagem ext4 de system e integrar APKs ARM32 compativeis de forma reproduzivel.
- O File Explorer ja existe como `/system/priv-app/MiFileExplorer/MiFileExplorer.apk`. Chrome, YouTube TV e VLC ainda nao estao instalados e nao havia APK correspondente no diretorio `downloads` na primeira busca.
## 2026-07-30 - YouTube oficial, DRM/VP9 e monitor persistente (v48)

- Objetivo confirmado pelo usuario: manter somente o YouTube oficial, sem tres clientes diferentes. O pacote escolhido e `com.google.android.youtube.tv` versao `3.02.006`, instalado como APK base mais split `config.armeabi_v7a.apk`. O Android Pie desta ROM nao oferece `pm install-multiple`; a instalacao reproduzivel usa `pm install-create`, `pm install-write` e `pm install-commit`.
- O YouTube TV oficial 6.09.300 foi testado como base + split, mas envia blocos sem criptografia pela fila segura antes da associacao DRM e termina com erro 165. Foi removido. O 3.02.006 tolera a fase inicial e foi mantido.
- Modulos de midia Amlogic ARM64 compilados no container `android9-aquario`, fonte `infra/aidan/aosp9/hardware/amlogic/media_modules` (Khadas pie), com o mesmo kernel 4.9.113: `media_clock`, `firmware`, `decoder_common`, `stream_input`, `amvdec_h264`, `amvdec_mh264`, `amvdec_h265` e `amvdec_vp9`. Artefatos arquivados em `scratch/media-modules-arm64/`.
- Os oito modulos ARM64 foram carregados ao vivo e substituíram as copias ARM32 antigas em `/vendor/lib/modules`. Antes da substituicao, os originais foram arquivados no aparelho em `/data/local/tmp/aquario-backup-20260730/media-modules-arm32.tar`.
- O processo OMX roda como UID `mediacodec`, grupo primario `camera`. Os dispositivos `/dev/amstream*` estavam `media:system 0660`, causando `EACCES`. Ao vivo foram corrigidos para `media:camera 0660`; a fonte `ueventd.amlogic.rc` e o ramdisk v48 agora criam esses dispositivos com grupo `camera` permanentemente.
- O codec VP9 seguro requer memoria TVP. Com TVP desativado, a alocacao falhava. `echo 1 > /sys/class/codec_mm/tvp_enable` reserva cerca de 160 MiB dos 208 MiB do pool codec e permitiu alocar 72 MiB para VP9. O v48 escreve `tvp_enable=1` no `post-fs`, antes do servico OMX.
- `/vendor/lib/libomx_framework_alt.so` foi alterada em uma unica string de `.secure` para `.securX`, fazendo o codec com nome seguro usar buffers OMX normais enquanto o kernel continua em modo TVP. Backup no aparelho: `/data/local/tmp/libomx_framework_alt.before-l3.so`.
- Widevine original em `scratch/widevine/libwvhidl.so`, SHA256 `583901959fe10f265ec3e033616e6a528eee3fbcbbcf8d401b2b2f9168fc1ed1`.
- A variante Widevine intermediaria `scratch/widevine/libwvhidl-l3-session-share.so`, SHA256 `de72028819f6999df75247f9aaab5b99eded53c2286b92656daae993015d6555`, neutraliza a condicao de compartilhamento de sessao em offset de arquivo `0x9e0ec` e a exigencia de decoder seguro em `0x159984`.
- O defeito final era a descriptografia insistir em uma sessao Widevine encerrada (`unable to find session: sid16`) mesmo depois de outra sessao receber a chave. A variante final `scratch/widevine/libwvhidl-l3-decrypt-fallback.so` troca dois bytes no offset de arquivo `0xa6588` por `43 e0`, desviando a falha de `CdmSessionMap::FindSession(session)` para o caminho interno que procura uma sessao pela key ID. SHA256 final `104b0e47d8169fdab41497bee0cd52e2b56b887cb7340ffcafa5b84c77daf04e`. Este e o hash implantado em `/vendor/lib/libwvhidl.so`; backup imediatamente anterior em `/data/local/tmp/libwvhidl.pre-decrypt-fallback.so`.
- Teste funcional conclusivo do YouTube oficial: deep link para `dQw4w9WgXcQ`, sessao `starboard_media` em estado 3, posicao 4222 ms e velocidade 1.0; metadata `Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)`. `/sys/class/vdec/vdec_status` confirmou `amvdec_vp9`, 1920x1080, 29 fps, 449 frames e zero drops/erros. Portanto rede, licenca Widevine, descriptografia e decodificacao VP9 por hardware funcionaram em conjunto.
- `org.smarttube.stable` foi desinstalado depois desse teste. `pm list packages` passou a listar somente `com.google.android.youtube.tv` entre os clientes YouTube/SmartTube.
- O desaparecimento do painel CPU/RAM/GPU foi localizado em `MetricsOverlayService`: o servico considerava seu proprio `StarterActivity` como ultimo evento de foreground e removia a overlay. A fonte foi corrigida para consultar diretamente `ActivityManager.getRunningTasks(1)`. Novo APK compilado no container Android 9 correto com `m -j16 AquarioMonitor`, SHA256 `ed5b8e31815b62749f66274535d49c96f9b18ea75222978608591778a9e775fa`, e implantado em `/system/priv-app/AquarioMonitor/AquarioMonitor.apk`; backup anterior em `/data/local/tmp/aquario-backup-20260730/AquarioMonitor.apk`.
- O build do APK exige ocultar temporariamente `hardware/amlogic/media_modules/drivers/amvdec_ports/test/Android.mk`, pois ele referencia `/vendor/amlogic/external/ffmpeg` fora da arvore permitida. O arquivo foi restaurado automaticamente apos o build.
- Boot persistente produzido: `work/teste-khadas-fresh-20260730-apps-metrics-v46/boot-khadas-fresh-p281-apps-metrics-media-v48-padded-16m.img`, SHA256 `0024bf34d59efb2521aad876046bd3e086b8a15d2e2c379cf925d11cdd4f1567`. Ele conserva kernel 8.502.226 bytes, DTB/second 57.837 bytes, page 2048 e todos os enderecos/cmdline do v47; adiciona carga ordenada dos oito modulos ARM64, TVP precoce e permissoes `amstream` corretas.
- Correcao sobre a anotacao anterior: o v48 foi gerado corretamente, mas a primeira tentativa de grava-lo nao alterou a particao. O `dd` do Toybox nao aceita `conv=fsync`; o erro tinha sido ocultado por `2>/dev/null`, e o readback diferente revelou que o v47 continuava instalado. O aparelho ainda inicializou e carregou os novos modulos porque as copias ARM64 ja estavam em `/vendor/lib/modules` e o v47 possuia o mecanismo existente de carga.
- O TVP foi observado novamente em zero depois do boot v47, pois um servico vendor o reinicializa depois de `post-fs`. A correcao final tambem executa `echo 1 > /sys/class/codec_mm/tvp_enable` no inicio de `init.aquario.postboot`, depois de `sys.boot_completed`.
- Boot final substituto: `work/teste-khadas-fresh-20260730-apps-metrics-v46/boot-khadas-fresh-p281-apps-metrics-media-v49-padded-16m.img`, SHA256 `b0f811390f6f329198b0d347560f0bebf3dd6d14a70d0ec346879daddfe08f7f`. Foi enviado primeiro a `/data/local/tmp/boot-v49-padded-16m.img`; hash local e do upload coincidiram. Gravacao correta: `dd if=/data/local/tmp/boot-v49-padded-16m.img of=/dev/block/boot bs=1048576` seguida de `sync`. O readback integral de `/dev/block/boot` coincidiu exatamente com `b0f811390f6f329198b0d347560f0bebf3dd6d14a70d0ec346879daddfe08f7f` antes do reinicio.
- Validacao apos reinicio frio do v49: `/dev/block/boot` manteve SHA256 `b0f811390f6f329198b0d347560f0bebf3dd6d14a70d0ec346879daddfe08f7f`; `sys.boot_completed=1`; `tvp_flag=1`; os oito modulos ARM64 estavam carregados; `/dev/amstream*` apareceu como `media:camera` e acessivel ao OMX; apenas `com.google.android.youtube.tv` apareceu entre os pacotes YouTube/SmartTube.
- Reproducao oficial repetida depois do boot frio usando a Activity `ShellActivity`: `starboard_media` ativo, playback state 3, posicao 4345 ms, velocidade 1.0, metadata correta do video de teste. Decoder `amvdec_vp9` em 2560x1440, 25 fps, 484 frames, zero drops, zero frame errors e zero hardware errors. Nenhum `OnPlayerError`, `CryptoException`, `ERROR_NO_KEY`, sessao Widevine ausente ou excecao fatal foi encontrado no log do teste.
- Depois de sair do YouTube e voltar ao launcher, `com.google.android.tvlauncher/.MainActivity` ficou resumida e a janela `Aquario performance monitor` reapareceu visivel (`Surface shown=true`) com valores reais, por exemplo `CPU 14% RAM 615 MB usada / 371 MB livre GPU 0%`. Isto confirma a correcao de reaparecimento do painel.
- O conjunto ativo `work/default-apps-wpa3-v45/install-set/youtube/` agora contem somente os APKs oficiais 3.02.006 testados: base SHA256 `9588040697a64becb06f5a81968da48bd27180a59000ecc71e96300a2f528b4b` e split ARMv7 SHA256 `b3a4bdf7af3e4f3c6398868eedc59f1dc2052e3d689e1b76e2ff690b45d9415c`. SmartTube, Tubesky e conjuntos oficiais mais novos que falharam foram movidos para `work/archives/youtube-alternatives-20260730/`, fora do conjunto de instalacao.
- As sugestoes do YouTube oficial demoraram o primeiro ciclo de inicializacao, mas foram confirmadas no `TvProvider`: canal 11 `Recomendados para voce`, `browsable=1`, mais canais `Em alta` e `YouTube Music`, com quinze preview programs publicados. A captura `scratch/launcher-channels.png` mostrou a linha YouTube e suas miniaturas no launcher. Para manter a renovacao, `com.google.android.youtube.tv` foi retirado do estado idle, adicionado a whitelist do Device Idle e recebeu `RUN_IN_BACKGROUND`; as mesmas operacoes foram adicionadas ao `init.aquario.postboot` da fonte e do ramdisk de trabalho.

## 2026-07-30 - aplicativos permanentes e imagem system ampliada

- O suporte a APKs split preassinados foi corrigido em `infra/aidan/aosp9/build/make/core/prebuilt_internal.mk`: modulos com `LOCAL_CERTIFICATE := PRESIGNED` agora copiam/alinhavam os splits sem procurar chaves inexistentes `PRESIGNED.pk8`. O teste opcional `vcode_m2m` em `hardware/amlogic/media_modules/drivers/amvdec_ports/test/Android.mk` passou a ser incluido somente quando a arvore proprietaria ffmpeg existe.
- Foram integrados ao produto `aquario_stv3000`: YouTube TV oficial `3.02.006` ARMv7, Chrome oficial com seus splits, atalho Leanback `de.eye_interactive.atvl.chromebrowser`, Prime Video oficial `com.amazon.amazonvideo.livingroom` `6.24.4+v16.0.0.103-allAbis`, Netflix oficial `com.netflix.ninja` `11.0.1 build 19770` e Aurora Store. Os modulos estao em `device/aquario/stv3000/prebuilts/apps/Android.mk` e `device.mk`.
- O wrapper Leanback do navegador foi compilado a partir de `device/aquario/stv3000/BrowserShortcut`; ele abre o pacote oficial `com.android.chrome`, permitindo que o navegador apareca no launcher de TV.
- A particao system completa foi copiada somente para leitura e arquivada como `scratch/permanent-20260730/system-current-full.img.zst`. A imagem de trabalho `scratch/permanent-20260730/system-permanent.img` foi ampliada de aproximadamente 983 MiB para 1,81 GiB, passou `e2fsck` e recebeu Chrome, YouTube, wrapper Leanback, Prime Video, Netflix e Aurora com UID/GID 0, diretorios 0755, arquivos 0644 e contexto `u:object_r:system_file:s0`.
- Depois da insercao dos aplicativos, o ext4 permaneceu limpo: 475.136 blocos de 4096 bytes, 181.237 blocos livres, cerca de 708 MiB. A imagem ainda precisa ser gravada com `/system` desmontado, por rescue/initramfs; nao deve ser sobrescrita enquanto o Android estiver usando a particao.
- Prime Video abriu e permaneceu resumido sem crash. Netflix abriu, mas mostrou `ui-800-3`; limpar dados nao resolveu. Rede e DNS funcionam, Widevine L3 responde, mas `ro.serialno` e `ro.boot.serialno` estao vazios, `ro.build.characteristics=default`, o modelo e `Aidan's ROM` e nao existe `ro.nrdp.modelgroup`. A hipotese principal e identidade/provisionamento/certificacao Netflix, nao falha de instalacao. A captura fornecida esta em `/home/fabiano/Imagens/Capturas de tela/Captura de tela de 2026-07-30 08-29-28.png`.

## 2026-07-30 - Aurora Store oficial permanente

- O usuario autorizou manter Aurora Store permanentemente. Ela e um cliente livre e nao oficial para consultar e baixar aplicativos da Google Play; neste projeto ela tambem permite obter o split ARMv7 correto sem depender da interface da Play Store.
- Aurora 4.8.3, versionCode 75, SHA256 `f30ee9e952c76c4d7f46adb90d11a1cbaa23ee87fb9f6ca2ce18d914355fde85`, e 4.7.5, versionCode 71, foram testadas e rejeitadas para a imagem final. Ambas abrem o onboarding, mas depois usam APIs posteriores ao Android 9, incluindo `android.text.Layout$TextInclusionStrategy` ou `android.view.WindowInsetsAnimation$Callback`, e podem deixar a interface vazia.
- A versao escolhida e a oficial Aurora Store 4.5.1, package `com.aurora.store`, versionCode 60, minSdk 21, targetSdk 34, SHA256 `f528f5616af3f55e242d460ee46b6ad8754c03241e76193310fa755069e56a0a`.
- O certificado foi conferido contra o projeto oficial: SHA1 `94:42:75:D7:59:8B:C0:3E:48:85:06:06:42:25:A7:19:90:A2:22:02`, SHA256 `4C:62:61:57:AD:02:BD:A3:40:1A:72:63:55:5F:68:A7:96:63:FC:3E:13:A4:D4:36:9A:12:57:09:41:AA:28:0F`.
- Validacao real: login anonimo efetuado, `https://auroraoss.com/api/auth` retornou HTTP 200, `android.clients.google.com/fdfe/getHomeStream` retornou HTTP 200 e o catalogo foi renderizado. A captura `scratch/aurora-451-sendevent.png` mostra a tela principal, inclusive Globoplay oferecido para o perfil do aparelho.
- O prebuilt 4.5.1 esta em `infra/aidan/aosp9/device/aquario/stv3000/prebuilts/apps/AuroraStore/base.apk`; `m -j16 AquarioAuroraStore` compilou com sucesso e o APK resultante foi inserido na imagem system offline. O script reproduzivel da insercao e `scratch/permanent-20260730/add-streaming-apps.debugfs`.
- Como `/system/bin/input` ainda aborta com SIGABRT nesta ROM, a navegacao automatizada foi feita pelo dispositivo separado `/dev/input/event5` (`virtual-search`) usando DPAD/ENTER via `sendevent`. Isso tambem confirmou que a Aurora 4.5.1 aceita navegacao por controle.

## 2026-07-30 - gravacao permanente do system e assinatura do YouTube

- A imagem `scratch/permanent-20260730/system-permanent.img`, com 1.946.157.056 bytes, foi gravada integralmente em `/dev/mmcblk1p18` pelo rescue TFTP. No rescue, o node nao era criado automaticamente; `/proc/partitions` confirmou major/minor `179:146` e foi necessario executar `busybox mknod /dev/mmcblk1p18 b 179 146`. O readback completo da particao coincidiu com o hash da imagem daquela etapa.
- O YouTube inicialmente nao foi aceito como app de sistema: `Failed to collect certificates from /system/priv-app/AquarioYouTube/AquarioYouTube.apk`. A causa foi o fluxo AOSP modificar com zipalign um APK base assinado apenas com APK Signature Scheme v2, invalidando a assinatura.
- `device/aquario/stv3000/prebuilts/apps/Android.mk` agora usa `LOCAL_REPLACE_PREBUILT_APK_INSTALLED` no APK base do YouTube. `build/make/core/prebuilt_internal.mk` tambem foi ajustado para copiar splits `PRESIGNED` sem alterar bytes. A saida compilada ficou identica aos arquivos de origem: base SHA256 `9588040697a64becb06f5a81968da48bd27180a59000ecc71e96300a2f528b4b`; split ARMv7 SHA256 `b3a4bdf7af3e4f3c6398868eedc59f1dc2052e3d689e1b76e2ff690b45d9415c`.
- O APK base corrigido foi implantado ao vivo e na imagem offline. Depois do reboot, `com.google.android.youtube.tv` passou a aparecer com `SYSTEM` e `UPDATED_SYSTEM_APP`.
- Antes do Globoplay, a imagem offline limpa tinha SHA256 `c8a6fb29c6e6706324596adfd92d05b9747c3dcdacd0feea561f9030da044e70`.
- Foi criado `scripts/android/uinput_tap.c`, um injetor touchscreen absoluto via `/dev/uinput`, porque `input`/`app_process32` abortam nesta ROM. O binario ARM64 estatico `scratch/uinput_tap-arm64`, SHA256 `c125cdbb2518e823f6c5ca3d93819c1536eeeeb80accf9efbec7c4789359dd26`, usa timestamps `CLOCK_MONOTONIC` e conseguiu acionar botoes da Aurora de forma confiavel.

## 2026-07-30 - Globoplay oficial permanente

- A Aurora identificou o pacote oficial `com.globo.globotv`, versao `2.340.0`, versionCode `102359`, minSdk 23, targetSdk 35. O conjunto compativel com o aparelho possui base, `config.armeabi_v7a`, `config.pt` e `config.tvdpi`, total aproximado de 44,1 MiB.
- Como a interface do Package Installer ficou presa na confirmacao de origem desconhecida, a instalacao foi concluida de forma reproduzivel com `pm install-create`, quatro chamadas `pm install-write` e `pm install-commit`. `appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow` foi aplicado; a mesma restauracao foi adicionada ao postboot da fonte para sobreviver a factory reset.
- Hashes arquivados em `device/aquario/stv3000/prebuilts/apps/Globoplay/`: base `386cf4c2d6ce98c09cd922a89fe66fb3b43273a430e4cbcb4acf9004d5652d5f`; ARMv7 `dffa403aa29f5758986fb4939731ff7cb97834b39f5a09169216151ae60998bc`; portugues `f7eb799bd0dd5e84fd083379b51c0f533688467e29b00557fe682bb7357dca1b`; tvdpi `9f7278c435e44ebc65e391577369b984904dde9401641b854c3b2c11ce4f335f`.
- O modulo `AquarioGloboplay` foi adicionado a `prebuilts/apps/Android.mk` e `device.mk`. A compilacao no container `android9-aquario`, `m -j16 AquarioGloboplay`, terminou com sucesso e os quatro arquivos de saida ficaram byte a byte identicos aos originais assinados.
- O mesmo conjunto foi inserido em `/system/app/AquarioGloboplay` no cartao ativo e na imagem offline. Apos reboot, o Package Manager confirmou `SYSTEM`, `UPDATED_SYSTEM_APP`, ABI primaria `armeabi-v7a` e versao 2.340.0. A imagem offline passou por `e2fsck`, ficou com 170.675 blocos livres de 4096 bytes e SHA256 final `e24c14bbaa08676095d4cb483a550cafe7b6d8c306a65333508198e4f470f9e3`.
- O Globoplay inicia `com.globo.globotv/.splashtv.SplashActivity`, mas sofreu ANR em `androidx.work.impl.background.systemjob.SystemJobService` durante a saturacao global de I/O. Nao apareceu excecao Java fatal especifica do aplicativo; a validacao funcional de login/reproducao deve ser repetida depois de corrigir a carga de armazenamento.

## 2026-07-30 - diagnostico do cartao e tempestade de I/O

- O cartao do Android e `mmcblk1`, SDHC `SC32G` de 29,7 GiB, CID `0353445343333247803e151062015c00`. O DTB ativo limita o host SD a 25 MHz, 4 bits, 3,3 V; o kernel reporta timing SD high-speed.
- Em cada boot observado houve uma sequencia de timeouts entre aproximadamente 11 e 55 segundos: CMD18 e depois CMD13 retornaram `resp_timeout`, `-110`, com dez tentativas e variacao de `rx_phase`. Depois disso as particoes foram montadas. Nao surgiram novos timeouts do SD durante o uso posterior.
- Teste somente leitura de 64 MiB no inicio de `/dev/block/system`, apos limpar page cache: a 25 MHz transferiu 67.108.864 bytes em 11,673 s, aproximadamente 5,75 MB/s, sem novo timeout. A 12,5 MHz, clock real 12 MHz, levou 24,032 s, aproximadamente 2,79 MB/s, tambem sem timeout. O clock foi restaurado para 25 MHz. Reduzir o clock permanentemente nao apresentou beneficio.
- Durante o primeiro boot posterior a instalacao dos apps, `vmstat` mostrou 53% a 74% de iowait e varios processos em `__lock_page_or_retry`, incluindo Globoplay, Play Store e GMS. ZRAM de 256 MiB estava ativa, com cerca de 112 MiB usados. Ocorreram ANRs simultaneos em Globoplay, Play Store e GMS, mostrando saturacao global e nao um defeito isolado do launcher ou do Globoplay.
- O ramdisk ativo e o v49 customizado. Seu `/init.amlogic.rc` tem SHA256 `39bc62abcd5df0f1c9d749eeb8dee6948a8ef9e62c37859829acc4d755d933ab`, SSH v26 e servicos/HALs adicionais que ainda nao estao refletidos integralmente em `device/aquario/stv3000/init.amlogic.rc`. Substituir o ramdisk ativo diretamente pelo arquivo antigo da arvore causaria regressao. O diretorio de trabalho correto e `work/teste-khadas-fresh-20260730-apps-metrics-v46/ramdisk-root/`; ele deve ser reconciliado com a fonte antes da proxima compilacao completa.

## 2026-07-30 - boot v50 preserva politicas apos reset

- O ramdisk v49 foi reconstruido a partir do diretorio de trabalho correto, sem trocar seu `init.amlogic.rc`, kernel, DTB, SSH v26 ou servicos customizados. O novo postboot conserva a whitelist/AppOps de segundo plano do YouTube oficial e executa `appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow`.
- Ramdisk v50: `work/teste-khadas-fresh-20260730-apps-metrics-v46/ramdisk-apps-metrics-media-v50.img`, SHA256 `9a5188104e4c0fb23683384601e32871a2cfa9081b5f97ef17ac51c4079b13be`.
- Boot v50 sem padding: `work/teste-khadas-fresh-20260730-apps-metrics-v46/bootimgs/boot-khadas-fresh-p281-apps-metrics-media-v50.img`, SHA256 `8a9e44a1fad34bb47b61d3ee8588707399fad47e46e8ad18ca5f9cb96e70d0b7`.
- Boot v50 final de 16 MiB: `work/teste-khadas-fresh-20260730-apps-metrics-v46/boot-khadas-fresh-p281-apps-metrics-media-v50-padded-16m.img`, SHA256 `ce35bf8a9c722f18efca3ddad31dcd31736b0001be3ddb5ae900bfb964818df5`.
- O boot anterior foi salvo no aparelho em `/data/local/tmp/boot-before-v50-padded-16m.img`, hash v49 `b0f811390f6f329198b0d347560f0bebf3dd6d14a70d0ec346879daddfe08f7f`. Upload, gravacao em `/dev/block/boot` e readback integral do v50 coincidiram.
- Validacao apos reboot: `/dev/block/boot` manteve o hash v50; kernel `4.9.113`; `sys.boot_completed=1`; postboot terminou; `com.aurora.store` ficou com `REQUEST_INSTALL_PACKAGES: allow`; YouTube apareceu na whitelist do Device Idle e com `RUN_IN_BACKGROUND: allow`; monitor iniciou; Globoplay permaneceu `SYSTEM`/`UPDATED_SYSTEM_APP`.
- Captura HDMI `scratch/globoplay-after-50s.png` confirmou o Globoplay 2.340.0 funcional, com catalogo, imagens, menu lateral e foco de controle renderizados. Quando iniciado depois de o boot assentar, nao houve crash nem ANR.

## 2026-07-30 - limites de certificacao e testes oficiais do Netflix

- O erro do Netflix TV oficial foi detalhado como `ui-800-3 (307006)`. DNS, rota e validacao de rede estavam funcionando; o NetworkMonitor obteve HTTP/HTTPS 204 e o YouTube oficial continuou reproduzindo com Widevine L3 e VP9 por hardware.
- O Netflix TV oficial 8.3.10 build 12018, ARMv7, foi obtido e teve o certificado comparado com o 11.0.1. Ambos usam o certificado Netflix SHA256 `363863596ea99241eb71b1a985553aa604de3ea3c5f0c546742390e682164e6b`. O APK 8.3.10 tem SHA256 `1210457a430c073ed547617b05debe366a0b379575bb4ce8623bff5c04c23b79`, mas tambem terminou em `ui-800-3 (307006)`.
- O estado interno do cliente TV informou `whitelisted=true`, `blacklisted=false`, ESN baseado em `XIAOMAIDAN=S=ROM` e Widevine system ID 4445. O HAL registra `Could not load liboemcrypto.so. Falling back to L3`. A imagem Aquario Android 7.1.2 original tambem nao possui `liboemcrypto.so`, propriedades NRDP de certificacao ou Netflix TV; ela trazia o Netflix movel 4.16.7 build 15235 em `/pre_app/netflix-new.apk`.
- O APK movel original foi extraido como `scratch/aquario-original-netflix-new.apk`, SHA256 `0ba92cb7c7ddaa120bccce4377773982b240911e66dda2b85f89fce487ea7986`. Ele mantem a assinatura oficial, mas o servico atual responde com erro `-14`, por ser antigo demais.
- A Aurora/gplayapi oficial foi usada com o perfil ARMv7 `rm_4` para obter diretamente do Google Play o Netflix movel oficial 9.76.0 build 64304, minSdk 28. Arquivos: `scratch/netflix-mobile-9.76.0-64304/base.apk` SHA256 `6cedb58114c4c20e03ed5ec4eac955ef95f37baf8307a3d3677e1c3c78d9ad0c`; split ARMv7 `53c90e87484f6d0224d64b46d06761b98ebf264dc8dea40762a27a044ddfe824`; ingles `ba752bf62eac0e59a38256e66a63bb7f59af5cdf2710dedfdbe38523cb68d5e9`; hdpi `87d2331f5c0d72e43a88650e55d2c4f7e89147f89e88b8bcd400f291e617aa96`. Todos usam o certificado oficial Netflix.
- Sem precompilacao, o 9.76.0 permaneceu preto por minutos e sofreu ANR. `cmd package compile -f -m speed com.netflix.mediaclient` terminou com sucesso e fez o logo Netflix aparecer em cerca de 30 segundos, mas o app continuou no splash por mais de dois minutos, provocou ANRs concorrentes e terminou derrubando a saida HDMI/HWC. O aparelho tem aproximadamente 1 GiB de RAM, usava zram/swap e chegou a 116% de iowait durante a compilacao no SD.
- Conclusao: o Netflix movel atual e pesado demais para uma experiencia utilizavel neste hardware/cartao, e o Netflix TV exige provisionamento/certificacao de fabricante que nao existe nem na ROM original. Nao foram usados APKs modificados nem falsificacao de DRM. O teste movel e o pacote Aurora de diagnostico foram removidos; a Aurora oficial foi restaurada para 4.5.1 versionCode 60 e ficou apenas o Netflix TV oficial 11.0.1 versionCode 19770, ja presente na fonte e na imagem permanente.
- Capturas do teste: `scratch/netflix-mobile-976.png` (preto antes de AOT), `scratch/netflix-mobile-976-aot-30s.png` (logo apos AOT), `scratch/netflix-mobile-976-aot-75s.png` (splash prolongado) e `scratch/netflix-mobile-976-aot-135s.png` (perda do sinal HDMI). A recuperacao controlada esta em `scratch/post-netflix-cleanup.png`.

## 2026-07-30 - utilitarios de diagnostico da Aurora

- `scripts/android/uinput_tap.c` agora aceita varios pares de coordenadas na mesma instancia e os tempos configuraveis `UINPUT_SETTLE_MS`, `UINPUT_HOLD_MS` e `UINPUT_INTERVAL_MS`. Isto evita criar e destruir um touchscreen virtual para cada toque, evento que fazia o Android relancar configuracoes e fechar menus.
- Binario ARM64 estatico final do utilitario: `scratch/uinput_tap-arm64-v3`, SHA256 `f3dd9f949fd034aed6a5cb02f33069ab65b0c00c32bb8030f65806db91d26265`.
- Fontes oficiais temporarias usadas no diagnostico: `scratch/AuroraStore-src-4.4.4-20260730` e `scratch/gplayapi-src-3.2.11-20260730`. A Activity de consulta manual foi compilada somente no package debug `com.aurora.store.debug`; esse pacote foi desinstalado e nao faz parte da imagem final.

## 2026-07-30 - Netflix removido e canais do YouTube esclarecidos

- Por decisao do usuario, o Netflix foi removido da instalacao ativa e da imagem permanente, pois o cliente TV oficial sempre termina em `ui-800-3 (307006)` neste hardware nao provisionado.
- No aparelho, `/system/app/AquarioNetflix/AquarioNetflix.apk` e seu diretorio foram apagados; `pm uninstall --user 0 com.netflix.ninja` removeu o estado do usuario. Depois do reboot, `pm list packages` confirmou ausencia de qualquer pacote Netflix.
- `AquarioNetflix` foi retirado de `device/aquario/stv3000/device.mk`, e o modulo correspondente foi removido de `prebuilts/apps/Android.mk`. O APK de referencia ficou fora da arvore ativa em `work/archives/netflix-disabled-20260730/netflix-tv-11.0.1-base.apk`, SHA256 `0dd3b3766c313ad2917ffe60e982e42e6ac100564b90ee97705c5519d6b49a4e`; ele nao sera incluido em novas compilacoes.
- A imagem `scratch/permanent-20260730/system-permanent.img` teve `/system/app/AquarioNetflix` removido por `debugfs`, passou `e2fsck` sem erros e agora tem SHA256 `024be223d089e7537f993b00c6b77f8cbf41aec4d94d2657bcb61fc19cd187b1`. Restaram 281.513 de 475.136 blocos usados.
- Existe somente um pacote YouTube instalado: `com.google.android.youtube.tv`, versionCode `302006320` (3.02.006). A aparencia de dois YouTubes no Home vem de dois canais `TYPE_PREVIEW` do mesmo aplicativo que estao marcados como visiveis no `TvProvider`: ID 11 `Recomendados para voce` e ID 13 `YouTube Music`. O canal ID 12 `Em alta` existe, mas esta com `browsable=0`.
- O icone YouTube na faixa superior e o atalho do unico aplicativo; as duas faixas verticais abaixo sao canais de conteudo/recomendacoes, nao instalacoes ou APKs duplicados.
- Captura apos a remocao: `scratch/final-launcher-without-netflix-2.png`.

## 2026-07-30 - chip de 8 GB reconhecido como eMMC, mas sem escrita efetiva

- O chip recentemente instalado nao foi reconhecido como NAND paralela. No U-Boot, o PHY NAND retornou `reset failed`, `get_chip_type ... fffffffe`, `chip detect failed` e `nandphy_init failed`.
- `store init 3` e `mmc dev 1` identificaram o chip no `SDIO Port C` como MMC 4.41, fabricante `0x65`, OEM `0x646f`, nome `M MOR`, barramento de 8 bits e capacidade de 7,2 GiB. O cartao Android continua sendo o `SDIO Port B`, `SC32G`, 29,7 GiB.
- O kernel confirmou `/dev/block/mmcblk0`, CID `65646f4d204d4f521290000007265800`, data 05/2021, 7.570.432 KiB, boot0/boot1 de 2 MiB e RPMB de 128 KiB. `life_time=0x00 0x00` e `pre_eol_info=00`, valores que este chip nao fornece de forma util.
- A tabela Amlogic do eMMC nao e valida: `partition verified error` e `mmc read partition ERROR`. O Android continuou montando todas as particoes a partir do SD `mmcblk1`.
- Teste reversivel no ultimo 1 MiB, setor inicial decimal 15.138.816 (`0xe70000`): o original tinha SHA256 `ad22545f157ce9ed34f2e1d65257671a5c753bcf2ffe7912575faa05305e7ab8`; o padrao aleatorio tinha `0f271db1dfda0411fa234626ac3c1a543b3781e215732560f698bdff42ef11c4`. O kernel informou escrita de 1 MiB, mas o readback manteve exatamente o hash original.
- O teste foi repetido diretamente no U-Boot. Backup em RAM teve CRC32 `086c145e`; padrao de 1 MiB preenchido com `0xa5` teve CRC32 `bf513fe6`. `mmc write` informou `2048 blocks written: OK`, mas `mmc read` devolveu CRC32 `086c145e`, o conteudo original. A restauracao tambem foi executada e confirmou `086c145e`.
- Conclusao: o eMMC responde a identificacao e leitura, mas nao efetiva gravacoes, apesar de kernel e U-Boot exibirem sucesso e `ro=0`. Isso e compativel com chip defeituoso, falso/recondicionado ou em modo interno de protecao somente leitura. Ele nao e confiavel para instalar o Android.
## 2026-07-30 - logo animado Aquario/Android v53 no U-Boot e Android

- Foi substituido o logo estatico por uma identidade de boot com fundo preto, wordmark `android`, arco do robo em verde, subtitulo `AQUARIO / ANDROID 9` e spinner circular de 12 segmentos coloridos. As fontes reproduziveis ficam em `assets/boot/android-aquario-base.svg`, `assets/boot/android-aquario-spinner.svg` e `assets/boot/desc.txt`.
- O gerador reproduzivel e `scripts/android/generate_aquario_boot_animation.sh`. Ele roda no container Ubuntu 22.04, instala ImageMagick/librsvg no container, gera 24 quadros Android 1920x1080 a 24 fps e 12 quadros BMP3 para o U-Boot. O ZIP Android final esta em `work/android-aquario-loading-v53/bootanimation.zip`, tem 2.146.011 bytes, entradas sem compressao e SHA256 `8e2979cd02235c633659a4c9d1ccede66e3fe816a7b630016aed9d6da116ffe5`.
- O posicionamento `bmp display ... m m` deste U-Boot foi testado pelo TTL e nao centraliza: ele desenha o bitmap no inicio do framebuffer. A v53 resolve isso com BMPs de tela inteira 1920x1080, 6.220.854 bytes cada, preenchidos ate 8 MiB. Assim o conteudo ja chega centralizado e nao depende das coordenadas defeituosas.
- O construtor final e `scripts/build_aquario_uboot_loading_v53.sh`. U-Boot v53: `work/uboot-loading-v53-20260730/bootloader-sd-loading-v53-4m.bin`, 4.194.304 bytes, SHA256 `eec8e44fa4f5558b88003a2a82bc4849ab099567044978d0f5eda14ef6cfdda1`. A reextracao FIP/LZ4C reproduziu exatamente o BL33 modificado.
- A animacao U-Boot usa 12 blocos de 8 MiB a partir do setor `0x272000`, passo `0x4000`: quadros 0-5 em `preboot/logo_a`, contador de autoboot de 1 s, quadros 6-11 em `aquario_logo/logo_b`, e depois `aquario_sd`. O ultimo quadro termina no setor `0x2a2000`; a Android boot image comeca em `0x2ae000`, deixando ainda `0xc000` setores, ou 24 MiB, sem sobreposicao.
- O bootloader anterior v52 foi salvo no aparelho em `/data/local/tmp/bootloader-before-loading-v53-4m.bin`, SHA256 `f7f1b3b999c8bf76f195f39eb824176c2598e2318573220146a7978be9caccad`. O pacote de implantacao v53 e `work/deploy-boot-loading-v53-20260730.tgz`, 5.082.078 bytes, SHA256 `4eb1dc1ca995dc1aa977fd19a79310007ed68ee6ccf5de0143f1440522e7ba5f`.
- O U-Boot v53 e os 12 quadros foram gravados diretamente em `/dev/block/mmcblk1`. O readback do bootloader retornou o SHA v53 exato. Os 12 readbacks individuais de 8 MiB tambem coincidiram, quadro por quadro, com os artefatos locais.
- O ZIP foi instalado em `/system/media/bootanimation.zip`, root:root 0644, e o hash no aparelho coincide com v53. A integracao compilavel fica em `infra/aidan/aosp9/device/aquario/stv3000/media/bootanimation.zip`, copiada por `device.mk` para `system/media/bootanimation.zip`.
- A imagem offline persistente `scratch/permanent-20260730/system-permanent.img` tambem recebeu o ZIP em `/system/media/bootanimation.zip`, inode root:root 0644; `e2fsck -fy` passou. SHA256 atual da imagem: `df942c2c62a0f76520666ff52d54413b9842bcc9ddcff59b78af069b24f80045`.
- Teste de boot automatico aprovado: o TTL confirmou as 12 leituras de 16.384 setores, a boot image em `0x2ae000`, `Starting kernel` e `uboot time: 9259524 us`. O tempo anterior tipico era cerca de 4,27 s, portanto a animacao em tela cheia acrescenta aproximadamente 5 s visiveis. Android concluiu com `sys.boot_completed=1`, `init.svc.bootanim=stopped`, e os hashes do U-Boot/ZIP permaneceram corretos.
- Provas pela placa HDMI: `scratch/uboot-loading-v52-proof.mp4` confirmou a rotacao dos quadros no prompt; `scratch/boot-loading-v53-full-boot.mp4` registrou o boot automatico v53 em tela cheia; os contatos estao em `scratch/boot-loading-v53-full-sheet-01.png` e `scratch/boot-loading-v53-full-sheet-02.png`. A placa repete o ultimo quadro e mostra barras durante renegociacao de sinal, portanto esses trechos nao representam o framebuffer real.
- Ha uma janela preta entre o `bootm` e a disponibilidade do compositor Android. Nao foi forcado o handoff do framebuffer: o U-Boot usa `0x3d800000`, enquanto o DTB ativo reserva somente 4 MiB em `0x3fc00000`; a regiao do U-Boot se sobrepoe aos pools ION/DI do kernel. Acrescentar `logo=osd1,loaded,0x3d800000,...` sem redesenhar o mapa de memoria poderia causar corrupcao. A solucao atual maximiza de forma segura as fases visiveis do U-Boot e do Android, mas nao elimina essa transicao do kernel.
- O servico de captura `pinhole-codex.service` foi restaurado ao final. O aparelho ficou no Android funcional, e nao no prompt do U-Boot.

## 2026-07-30 - handoff continuo do logo U-Boot para kernel, v54-v57

- A conclusao cautelosa registrada na v53 foi superada por teste real. O kernel Amlogic 4.9 possui suporte nativo ao framebuffer herdado por `logo=osd1,loaded,<endereco>,<modo>`. A v54 passou a usar:
  `logo=osd1,loaded,0x3d800000,1080p60hz fb_width=1920 fb_height=1080 vout=1080p60hz,enable hdmimode=1080p60hz`.
  O aparelho iniciou repetidamente sem corrupcao e o kernel confirmou `fb: osd probe OK` e `hdmitx: hw: alread display in uboot 0x10`.
- A v54 ainda mostrou duas lacunas na captura, de aproximadamente 6,13 s e 3,23 s. O TTL isolou a causa no binario proprietario `systemcontrol`: ele apagava OSD0/OSD1, solicitava temporariamente o modo EDID `2160p30hz` e, logo depois, o init restaurava `1080p60hz`.
- A v55 alterou `drivers/amlogic/media/vout/hdmitx/hdmi_tx_20/hdmi_tx_main.c`. Enquanto `get_logo_loaded()` esta ativo, `set_disp_mode_auto()` mantem o VIC fisico herdado do U-Boot e adia um VIC diferente. O TTL confirmou `preserve U-Boot VIC 16 while logo is active; defer VIC 95` e depois `ALREADY init VIC = 16`.
- A v56 alterou `drivers/amlogic/media/osd/osd_fb.c`. `osd_blank()` ignora pedidos para apagar somente o plano que contem o logo herdado e somente enquanto `get_logo_loaded()` esta ativo. O TTL confirmou `keep boot logo visible; ignore blank from systemcontrol`.
- A captura v56 revelou o ultimo defeito: embora o HDMI permanecesse em 1080p, a notificacao logica temporaria de 2160p ainda redimensionava o plano OSD de `(0,0,1919,1079)` para `(0,0,3839,2159)`, deixando-o invisivel ate o retorno a 1080p.
- A v57 alterou `drivers/amlogic/media/osd/osd_logo.c`. `set_osd_logo_freescaler()` agora preserva a geometria do logo herdado quando ele ja ocupa exatamente o framebuffer declarado e o modo temporario diverge. O TTL do kernel `#19` confirmou:
  `keep U-Boot logo geometry 1920x1080; ignore temporary mode 2160p30hz`.
- O compositor continua assumindo normalmente a tela e limpando `logo_loaded`; portanto troca de resolucao e blank posteriores ao boot nao sao bloqueados. O Android v57 terminou com `sys.boot_completed=1`, `1080p60hz`, Linux `4.9.113 #19`, e o monitor CPU/RAM/GPU voltou no launcher.
- A captura final de 110 segundos e `scratch/boot-handoff-v57-full.mp4`. O `blackdetect` (`d=0.2`, `pix_th=0.02`) nao encontrou nenhum intervalo preto. As folhas `scratch/boot-handoff-v57-sheet-01.png`, `-02.png` e `-03.png` mostram barras geradas pela placa durante a perda de sinal do reset e, em seguida, o logo continuo por toda a passagem U-Boot/kernel/bootanimation. A lacuna preta observada nas v54-v56 foi eliminada.
- Kernel v57 `Image.gz`: SHA256 `b5ac7171cce3a6f3b96f9e645bdf5f0823ec1b14c2e7a75da25609a1f8159dd4`. Foi compilado no container correto `android9-aquario`, toolchain AArch64 GCC 4.9, `-j16`.
- Construtores reproduziveis: `scripts/build_aquario_boot_handoff_v56.sh` aceita `VERSION` e continua gerando v56 por padrao; `scripts/build_aquario_boot_handoff_v57.sh` seleciona v57.
- Boot v57 sem padding: `work/boot-handoff-v57-20260730/boot-aquario-handoff-v57.img`, SHA256 `1684c357741656e618bee4283ddcfbf6b14c5455a4229098c6f6db7e33372725`.
- Boot v57 final de 16 MiB: `work/boot-handoff-v57-20260730/boot-aquario-handoff-v57-padded-16m.img`, SHA256 `ab485608a9954014934f80970fc681469a906737548ebd4bb1470d54cacd55c7`.
- A v57 foi gravada em `/dev/block/boot`; o readback integral apos o reboot coincidiu com `ab485608...`. A v56 anterior esta preservada no aparelho em `/data/local/tmp/boot-before-v57-16m.img`, SHA256 `297e2d5d76113a65a6fb5e0ac91ce42af13a3091f122fa225cd6d2dfa63f7546`.

## 2026-07-30 - diagnostico dos timeouts iniciais do SD, v58-v61

- O armazenamento do Android atual e um cartao SDHC `SC32G` de 29,7 GiB, 25 MHz/4 bits. Identidade: CID `0353445343333247803e151062015c00`, fabricante `0x03`, OEM `0x5344`, SCR `0235804300000000` e CSD `400e00325b590000edc87f800a404000`.
- O eMMC, quando presente, usa outro host (`emmc`) e foi observado em 50 MHz/8 bits. Todas as tentativas desta rodada foram condicionadas ao host `sd`; frequencia, largura de barramento e politica de erros do eMMC nao foram alteradas.
- O atraso vem da primeira leitura normal pelo block layer. O controlador Amlogic aguarda aproximadamente 4,15 s por tentativa e repete dez vezes, alternando `rx_phase` entre 0, 1, 2 e 3. Depois do erro ser devolvido, a recuperacao/reset feita pelo block layer permite que as leituras seguintes funcionem.
- A v58 marcou apenas o disco do host `sd` com `GENHD_FL_NO_PART_SCAN`, deixando a tabela Amlogic MPT criar as particoes. As particoes apareceram cedo, mas o primeiro `CMD18` normal ainda travou. Kernel `Image.gz` SHA256 `9049b62d6120fd5461351723ca4d7b8747039c6ebaa1f3adebf036499fcfbd91`; boot de 16 MiB SHA256 `264a97d309e7ebe0543d7c0e62ca5ca66ebfebae90039c5a4eb99d82fb9cebfa`.
- A v59 adicionou `MMC_QUIRK_BLK_NO_CMD23` somente ao `SC32G`. Nao houve melhora; portanto a hipotese de `CMD23` foi descartada e a quirk foi removida da fonte. Kernel SHA256 `d22800c468fc2e2ac0a9ecfedbe3f2da0d515b85aebd2f8b0e73b7129429859f`; boot de 16 MiB SHA256 `99668ce71a4e7446f9684656621e9c9e369afd61a7af494fd88243c1d3146667`.
- A v60 fez um `mmc_hw_reset()` preventivo somente no `SC32G`, antes de expor o disco. O reset retornou zero, mas mudou a falha de `CMD18` para `CMD17` e impediu a leitura MPT de concluir. O Android esperou 90 s pelas particoes e entrou em reboot, que ficou bloqueado em `_mmc_sd_suspend`. A hipotese foi descartada e o reset preventivo foi removido. Kernel SHA256 `c3f8ae79da351530dc5a025e7e6d4ba69f90d6a469e63399c70e52c0e9942f97`; boot de 16 MiB SHA256 `71be5c4c83c618b567d66637ab17c9a6336c1bcb84a89165090993855d8c663e`.
- A v61 preserva apenas a varredura MPT exclusiva do host `sd` e altera a politica de timeout exclusivamente quando todas estas condicoes coincidem: tipo SD nao-SDIO, hostname `sd`, nome `SC32G`, fabricante `0x03` e OEM `0x5344`. Nesse caso, o primeiro timeout e devolvido sem as dez repeticoes do controlador, para o block layer iniciar logo sua recuperacao. O ramo eMMC continua usando `AML_ERROR_RETRY_COUNTER` sem nenhuma mudanca.
- A v61 foi compilada no container `android9-aquario`, GCC AArch64 4.9, `-j16`, Linux 4.9.113 `#23`. Kernel `Image.gz` SHA256 `ae6f35a163862b56d65276a2b77d52d789e1aac6ddf7df81079f1a86924b78b7`; boot final de 16 MiB SHA256 `1ea3e46b37b82e2536c681a5bf75fa514723b266ece0d16728a4d11d2a457fc8`.
- Construtor reproduzivel: `scripts/build_aquario_boot_handoff_v61.sh`. Imagem: `work/boot-handoff-v61-20260730/boot-aquario-handoff-v61-padded-16m.img`. Copia TFTP: `../recovery-lab/tftp_root/boot-aquario-v61.img`.
- Backups no aparelho: v57 antes da v58 em `/data/local/tmp/boot-before-v58-16m.img` (`ab485608...`), v58 antes da v59 em `/data/local/tmp/boot-before-v59-16m.img` (`264a97d...`) e v59 antes da v60 em `/data/local/tmp/boot-before-v60-16m.img` (`99668ce...`).
- Situacao ao encerrar esta anotacao: a v60 esta travada no caminho de reboot e nao subiu SSH. O kernel tem `CONFIG_MAGIC_SYSRQ=y`, mas mascara padrao `0x1`, que nao autoriza reboot por SysRq. E necessario um ciclo fisico de alimentacao, capturar o prompt U-Boot, gravar/testar a v61 e completar esta secao com o resultado real.

### Teste real v61 e preparacao v62

- A v61 foi transferida por TFTP, gravada no setor `0x2ae000` por 32.768 blocos e relida integralmente. Imagem em RAM e readback deram CRC32 `7fad1f92`; o SHA256 lido depois pelo Android em `/dev/block/boot` foi `1ea3e46b37b82e2536c681a5bf75fa514723b266ece0d16728a4d11d2a457fc8`.
- No primeiro boot v61, a MPT foi lida em `5,184850 s` e todas as particoes apareceram ate `5,190178 s`. O primeiro I/O normal falhou em `11,653789 s`; a politica rapida evitou as dez repeticoes, os `CMD13` de aborto terminaram em `11,974605 s`, `system/vendor/odm/product` montaram ate `12,227053 s` e o segundo estagio iniciou em `12,567469 s`. O atraso de aproximadamente 46 s caiu para cerca de 0,32 s.
- Esse primeiro boot completou com `sys.boot_completed=1`, bootanimation parada, HDMI `1080p60hz` e kernel `4.9.113 #23`. O eMMC permaneceu em 50 MHz/8 bits e o SD em 25 MHz/4 bits.
- O reboot normal expôs outra ordem valida: a primeira leitura que falhou foi o `CMD17` do proprio leitor MPT, em `10,451614 s`. O fail-fast devolveu o erro em `10,506247 s`, mas o codigo proprietario saiu sem criar particoes. Alem disso, foi encontrado um bug antigo em `aml_emmc_partition_ops()`: esse caminho de erro fazia `goto out` sem `mmc_release_host()`, causando o bloqueio posterior de reboot em `_mmc_sd_suspend`.
- A v62 corrige o caminho MPT somente para a identidade exata `SC32G` no host `sd`: apos falha da leitura inicial, executa `mmc_hw_reset()` e repete a leitura uma vez. Se ainda falhar, agora sempre libera o host antes de retornar. O eMMC nao entra nessa recuperacao e mantem seu caminho original.
- Kernel v62 `Image.gz`, Linux `#24`, SHA256 `159a51a2a60c485ad4237b1b3ecab6c505cc19b7ebe98cfa7e246d31da20bd6b`. Boot final de 16 MiB: `work/boot-handoff-v62-20260730/boot-aquario-handoff-v62-padded-16m.img`, SHA256 `fb3eab9f2f9e86befd8bb8e11522471fcaf6ab1cdf82ab37fb7ab4562a4d39b3`, CRC32 `374563ab`.
- Construtor: `scripts/build_aquario_boot_handoff_v62.sh`. Copia no volume TFTP ativo: `work/aquario-rescue-initramfs-v35/boot-aquario-v62.img`.
- A v61 travou ao tentar reiniciar depois do segundo teste, pois ainda continha o vazamento do host no caminho MPT. E necessario novo ciclo fisico de energia para gravar e testar a v62 em pelo menos dois boots consecutivos.

### v62 aprovada em dois boots consecutivos

- A v62 foi transferida por TFTP e gravada no setor `0x2ae000`, 32.768 blocos. CRC32 da imagem em RAM e do readback integral: `374563ab`. O Android confirmou depois o SHA256 de `/dev/block/boot`: `fb3eab9f2f9e86befd8bb8e11522471fcaf6ab1cdf82ab37fb7ab4562a4d39b3`.
- Primeiro boot v62, iniciado diretamente da imagem carregada: Linux `4.9.113 #24`; nenhuma falha SD. MPT validada em `6,497757 s`, particoes `vendor/odm/system/product` criadas ate `6,882215 s`, montadas ate `6,956677 s` e segundo estagio iniciado em `7,194546 s`. Android terminou com `sys.boot_completed=1`, bootanimation parada e HDMI `1080p60hz`.
- Segundo boot v62, feito por `reboot` normal e carregado automaticamente pelo U-Boot: reproduziu o caso dificil. O `CMD17` inicial expirou em `10,124282 s`; o fail-fast terminou em `10,167880 s`; `mmc_hw_reset()` exclusivo do `SC32G` retornou zero em `10,302239 s`; a repeticao MPT passou em `10,329495 s`. Particoes foram criadas ate `10,684160 s`, montadas ate `10,758846 s` e o segundo estagio iniciou em `10,988455 s`.
- O segundo boot tambem concluiu com `sys.boot_completed=1`, bootanimation parada, HDMI `1080p60hz`, kernel `4.9.113 #24` e SHA de boot ainda identico a v62. Nao houve espera de 90 s, dez retries de 4,15 s, reboot para bootloader ou deadlock.
- Isolamento de desempenho do eMMC comprovado no codigo e no TTL:
  - o fail-fast exige simultaneamente tipo SD nao-SDIO, hostname `sd`, nome `SC32G`, fabricante `0x03` e OEM `0x5344`;
  - a repeticao MPT/reset exige a mesma identidade exata e hostname `sd`;
  - o bypass da varredura generica testa hostname `sd`;
  - o eMMC continuou nos dois testes em 50 MHz/8 bits e conserva `AML_ERROR_RETRY_COUNTER`, seu fluxo de particionamento e sua configuracao de barramento originais.
- Portanto, ao transferir o sistema para um eMMC funcional, essas correcoes do cartao nao adicionam reset, espera, reducao de clock, reducao de largura de barramento ou retries extras ao eMMC.
- Estado final: Android funcional iniciado automaticamente do cartao com boot v62 persistente. Esta e a base aprovada para as proximas alteracoes.

## 2026-07-30 - v63: ponto verde no handoff U-Boot/kernel

- O requisito visual foi alterado para que o ultimo quadro do U-Boot nao deixe o circulo de loading congelado. Os quadros 0-10 continuam com o spinner; o quadro 11 mostra o mesmo logo/textos e somente o ponto verde central. Quando o `bootanimation` Android assume, o circulo volta a aparecer animado.
- Fonte nova: `assets/boot/android-aquario-hold-dot.svg`. O gerador `scripts/android/generate_aquario_boot_animation.sh` recebeu a opcao reproduzivel `UBOOT_FINAL_DOT_ONLY=1`; o wrapper final e `scripts/android/generate_aquario_boot_animation_v63.sh`.
- Saida: `work/android-aquario-loading-v63`. Os quadros U-Boot 0-10 foram comparados byte a byte com v53 e continuam identicos. Os 24 PNGs da animacao Android tambem continuam byte a byte identicos; somente o BMP U-Boot `frame-11` mudou.
- `frame-11.bmp`: 6.220.854 bytes, SHA256 `d3c988dddbf048935cc2089189cee0cba91c2c26010fb491080820167376b1d6`.
- Bloco final preenchido ate 8 MiB: `work/android-aquario-loading-v63/uboot/frame-11-raw-8m.bin`, SHA256 `ec4cd2c6d3c4dc18a19c0138b8c69314e8aec548853619021c1a3146e109cad0`.
- O inicio correto do quadro 11 e o setor `0x29e000` (decimal 2.744.320), com 16.384 setores (`0x4000`). `0x2a2000` e o setor imediatamente apos o quadro. Uma primeira escrita foi feita por engano nesse bloco livre; ela foi integralmente restaurada a partir do backup `/data/local/tmp/uboot-frame-11-before-v63-8m.bin`, e o readback restaurado confirmou SHA256 `1ff789afda0d419484c3bb4d680bf9ae8e305ffb79250151337d1dca8ddb9857`.
- O quadro 11 original correto foi salvo em `/data/local/tmp/uboot-frame-11-real-before-v63-8m.bin`, SHA256 `fdfef8b3caa54aa57ac978f0e251e4e58ef0b3b15d53242075e6b7b721842cc8`.
- O novo quadro foi gravado no setor correto `0x29e000`. Readback depois de varios boots confirmou SHA256 `ec4cd2c6...`. A imagem Android v62 em `/dev/block/boot` permaneceu intacta, SHA256 `fb3eab9f2f9e86befd8bb8e11522471fcaf6ab1cdf82ab37fb7ab4562a4d39b3`.
- Prova HDMI continua: `scratch/uboot-v63-full-handoff-wallclock.mp4`, SHA256 `1ca877bf8d21682a1c9c9b8fc7e61def34ee84a7d890352128665694dc0f49e4`. A folha `scratch/uboot-v63-full-handoff-contact.png`, SHA256 `59fe68cd4bcae65f7f58bf0e5b098ec5c0d1a8bf65c0c24fec8f3134b70ba3b9`, mostra em sequencia: spinner U-Boot, ponto verde isolado durante o handoff, spinner Android e launcher.
- Teste final: Android voltou com `sys.boot_completed=1`; `pinhole-codex.service` foi restaurado e ficou ativo.

## 2026-07-30 - captura integral do boot pelo TTL

- O broker usado por `conectar_ttl.sh` mantem um log continuo, em modo append, em `../recovery-lab/logs/serial_ttyUSB1.log`. Esse arquivo nao e truncado pelo novo coletor e inclui toda a atividade da porta, nao somente um boot.
- Foi criado `scripts/capture_aquario_full_boot_log.sh` para isolar automaticamente um boot completo: registra o offset atual do log continuo, reinicia o Android por SSH, espera o primeiro banner `U-Boot `, aguarda `sys.boot_completed=1` por SSH e conserva mais cinco segundos de TTL.
- Uso normal: `./scripts/capture_aquario_full_boot_log.sh`. Um diretorio explicito pode ser informado como primeiro argumento, por exemplo `./scripts/capture_aquario_full_boot_log.sh logs/boot-captures/meu-teste`. A origem tambem pode ser sobrescrita pela variavel `AQUARIO_SERIAL_LOG`.
- Primeira coleta aprovada: `logs/boot-captures/20260730-190239`. Comecou em `2026-07-30T19:02:39-03:00`, terminou em `2026-07-30T19:04:27-03:00`, capturou 317.615 bytes e confirmou `uboot_seen=1` e `sys.boot_completed=1`.
- `boot-serial.raw` e o recorte byte a byte do broker, SHA256 `532afb4911b27ce23b5e09f354ca01270965e4e0940d76f81328d176ad651c87`. `boot-serial.txt` comeca exatamente no primeiro banner do U-Boot, SHA256 `e13d611ae9b6e00142f9b30ab0609207f54a7f05951a3c4affcb5d2b21d75570`. `boot-serial-deduplicated.txt` remove somente linhas vazias e repeticoes consecutivas produzidas pelo TTL, SHA256 `3af94e2a7763248db977f5cf00a923ebf065bc6bb0462828604d00640b16d177`.
- A coleta contem U-Boot 2015.01, deteccao do `SC32G`, `Starting kernel`, Linux 4.9.113 `#24`, primeiro e segundo estagios do init, handoff preservado do framebuffer, link Ethernet, encerramento da bootanimation e atividade dos servicos Android depois da inicializacao. O estado `sys.boot_completed=1` e comprovado em `metadata.txt`, pois e consultado por SSH e nao depende de aparecer como texto no console serial.

## 2026-07-30 - diagnostico do boot integral v62/v63

Fonte analisada: `logs/boot-captures/20260730-190239/boot-serial-deduplicated.txt`, 2.260 linhas, com confirmacao externa de `sys.boot_completed=1`. A ordem abaixo representa prioridade pratica, nao apenas a palavra `error` no texto.

### Problemas de alta prioridade

1. **Politica SELinux e rotulos incompativeis.** O kernel inicia com `androidboot.selinux=permissive`. Mesmo assim, o log contem 79 contextos que a politica carregada nao reconhece, pelo menos 126 AVC denials e 30 ocorrencias de `audit: rate limit exceeded`. Ha arquivos de `system`, `vendor`, propriedades, dispositivos e sysfs como `unlabeled`. Isso mostra mistura de politica/`file_contexts` entre bases diferentes. Em permissive as operacoes continuam, mas ha custo de log e nenhuma protecao SELinux efetiva; em enforcing, partes essenciais como Mali, Wi-Fi, compositor, keymaster, `uinput` e scripts Aquario deixariam de funcionar.
2. **Pressao de memoria estrutural.** Com 1 GiB fisico, o kernel informou somente 642.572 KiB disponiveis no inicio porque 356.352 KiB, aproximadamente 348 MiB, ficam reservados em CMA. O maior bloco e `codec_mm_cma`, 208 MiB, alem de ION, DI e VDIN. Verificacao ao vivo apos o boot mostrou `MemAvailable=288392 kB`, `CmaFree=5528 kB` e cerca de 77 MiB da zram/swap ja usados. Nao houve OOM neste boot, mas essa margem pequena e um candidato forte para a lentidao com launcher e aplicativos.
3. **Inicializacao muito longa.** O U-Boot consumiu 9,249 s, parte intencional da animacao. O segundo estagio do init iniciou em 7,185 s de kernel, o compositor habilitou OSD0 em 27,197 s, Ethernet ficou ativa em 50,779 s e a bootanimation terminou em 65,478 s. A confirmacao de boot completo ocorreu antes do final da coleta em 87 s de kernel. Nao ha panic ou crash explicando o tempo; ele e acumulado por framework pesado, inicializacao tardia de rede/Wi-Fi, auditoria e hardware legado.
4. **Verificacao/manutencao de `/data` executada na ordem errada.** `/data` foi montada em 8,976 s. Depois disso, `tune2fs` tentou alterar quota e abortou porque o filesystem estava montado; `e2fsck` tambem abortou com exit 8 pelo mesmo motivo. Assim, a checagem real de integridade de `/data` nao ocorre no boot e a configuracao de quota pretendida nao e aplicada.
5. **Factory reset quebrado.** Aos 68,226 s, o init tentou iniciar `factoryreset`, mas `/system/bin/factoryreset.sh` nao existe. Qualquer fluxo que dependa desse servico falhara, inclusive restauracao de fabrica solicitada pelo Android/U-Boot.
6. **Gadget USB criado tres vezes.** Aos 69,419-69,459 s, o init tentou registrar `/devices/virtual/android_usb/android0` tres vezes. Isso gerou tres `WARNING: CPU`, tres stack traces e `-EEXIST`. Nao e kernel panic, mas revela scripts USB concorrentes/repetidos e pode explicar instabilidade do ADB; de fato o `adbd` foi morto por SIGKILL aos 78,055 s e reiniciado em seguida.
7. **Quadro 10 da animacao U-Boot corrompido no cartao.** Depois de ler o setor `0x29a000`, o U-Boot registrou `There is no valid bmp file at the given address`. Readback ao vivo dos 12 blocos confirmou que somente esse bloco diverge: esperado `839ebc073fc7aa49c8f700acb0ae53299376ea9e0f5166eb9e81ebc8e31bc015`, lido `633b5a5d20ed5448991467109928ad451803e3b6de44e5d1391d3899f9c8564f`. Os outros 11 blocos coincidem, inclusive o quadro final v63 em `0x29e000`. O efeito e um quadro pulado, sem impedir o boot.

### Problemas funcionais de prioridade media

8. **eMMC detectado, mas sem tabela Amlogic valida.** O kernel encontrou `mmcblk0`, eMMC `M MOR`, 7,22 GiB, 50 MHz/8 bits, incluindo boot0/boot1/RPMB. A leitura MPT falhou com `magic error` e `partition verified error`. Portanto o chip responde eletricamente, mas nao contem a estrutura Aquario esperada e o Android continua vindo do SD `mmcblk1`. Isso nao foi erro do SD v62: a MPT do `SC32G` passou de primeira neste boot e as particoes apareceram em 314 ms.
9. **Wi-Fi sobe com recuperacao e depois e parado.** A energizacao do SV6051P produz tres timeouts SDIO, chip ID inicial invalido, fallback Cabrio, endereco Amlogic invalido, falha de `mic hash` e ausencia de `/tmp/flash.bin` para SAR. Mesmo assim, o chip e identificado, firmware e calibracao carregam e `wlan0` aparece. O `wpa_supplicant` inicia em 53,032 s e e morto por SIGKILL em 57,744 s; nao ha associacao Wi-Fi no restante da captura. Ao vivo, `wlan.driver.status=unloaded` e `init.svc.wpa_supplicant=stopped`, enquanto Ethernet esta `up`. Pode ser desligamento deliberado por Ethernet, mas Wi-Fi nao ficou operacional neste teste.
10. **HALs Amlogic nao publicados corretamente.** O init repetiu 19 vezes que nao encontrou interfaces: dez para `vendor.amlogic.hardware.hdmicec@1.0`, seis para `systemcontrol@1.1` e tres para `systemcontrol@1.0`. O driver CEC do kernel conclui o probe, e o processo legado `systemcontrol` atua sobre o HDMI, mas os servicos HIDL/manifesto nao estao coerentes. CEC e recursos de configuracao dependentes desses HALs podem falhar ou iniciar tarde.
11. **Caminho DRM/seguranca incompleto.** `defendkey` falha no probe por memoria reservada insuficiente. O manipulador `verity-avb` inicia com nome de dispositivo vbmeta vazio, e contextos de Widevine, ClearKey, TEE e HDCP nao existem na politica carregada. Isso nao impede YouTube sem DRM, mas e um bloqueio provavel para Widevine/streaming protegido e impede tratar esta ROM como verified/secure.
12. **Troca HDMI desnecessaria durante o boot.** `systemcontrol` solicita temporariamente 2160p30 e logo volta para 1080p60. As correcoes v55-v57 preservam o VIC e a geometria do logo, portanto nao houve lacuna preta, mas continuam existindo notificacoes, trabalho do compositor e cerca de 0,5 s de churn. O kernel tambem registra `invalid vinfo1` e `monitor_timeout`; a saida final, entretanto, fica correta em 1080p60.
13. **Recursos incompletos no DTB para aceleradores e perifericos.** GE2D nao encontra o recurso de registradores, embora crie a workqueue; `picdec` falha com `-22`; VDIN nao obtem o clock de medicao; e clocks `clk_hevcb_mux`, `ahbarb0` e `asyncfifo` nao existem. Mali e H.264/H.265/VP9 carregam, portanto nao e ausencia total de aceleracao, mas esses buracos podem limitar composicao 2D, captura de video e alguns caminhos de codec.
14. **Audio parcialmente descrito.** A placa ALSA e HDMI PCM inicializam, mas as rotas analogicas `LOUTL/LOUTR -> Ext Spk` falham e os controles pinctrl S/PDIF nao existem. HDMI pode funcionar; alto-falante analogico e S/PDIF nao devem ser considerados validados.

### Fragilidades e avisos de menor prioridade

15. O U-Boot nao encontra DTB valido nas copias reservadas, nao encontra a particao `env` e usa `Using default environment`. Ele tambem usa parametros padrao para VPU/OSD. O boot funciona porque encontra o DTB correto dentro da Android boot image em `0x1ea7000`, mas o fluxo e fragil e `saveenv` nao tem armazenamento persistente valido.
16. A sondagem NAND falha porque nao ha NAND compativel; os timeouts iniciais CMD8/CMD55 fazem parte da sondagem de tipo de cartao. Sao mensagens esperadas na configuracao atual e nao causaram atraso relevante.
17. `/odm/default.prop` e `/odm/ueventd.rc` estao ausentes. O Android prossegue, mas a particao ODM esta incompleta e parte da configuracao especifica da placa foi absorvida por outros arquivos.
18. O numero de serie `ro.serialno` nao existe. Isso pode gerar identidade vazia/duplicada em ADB e aplicativos.
19. Ethernet funciona a 100 Mbps full duplex, mas PTP falha em cada subida de link. So afeta timestamping de precisao, nao acesso normal a rede.
20. Existem ainda probes nao essenciais incompletos: reset-controller ocupado (`-16`), `page_trace` sem sysfs, USB2 sem portas, DWC3 forcado para host, cache hierarchy nao detectada e clock gates de UART ausentes. Nenhum deles causou panic ou impediu o Android de completar.

### O que o log nao mostrou

- Nao houve kernel panic, Oops fatal, EXT4 I/O error, OOM, processo morto pelo low-memory killer, ANR ou crash explicito de launcher/SurfaceFlinger.
- Mali carregou corretamente e os modulos de decodificacao H.264, H.265 e VP9 inicializaram.
- O console TTL contem principalmente kernel/init. Erros Java de launcher, YouTube ou Play Services exigem uma captura paralela de `logcat`; a ausencia deles neste arquivo nao prova que os aplicativos estejam sem problemas.

### Classificacao por dificuldade de correcao

Esta escala considera uma correcao permanente e reproduzivel na ROM/bootloader, com teste de regressao. Apenas esconder mensagens do log seria mais facil, mas nao conta como solucao.

#### Muito baixa - minutos, risco pequeno

1. **Quadro 10 U-Boot corrompido (problema 7).** Regravar somente os 8 MiB do setor `0x29a000` com `frame-10-raw-8m.bin` e conferir SHA256. O trabalho e direto; a unica investigacao adicional e confirmar em boots futuros se foi erro isolado de gravacao ou se o cartao volta a corromper o bloco.
2. **Numero de serie ausente (problema 18).** Definir um `ro.serialno` estavel a partir de propriedade de boot, identificador da placa ou valor gerado uma vez. Precisa apenas evitar que varias imagens recebam a mesma identidade.
3. **PTP Ethernet falhando (problema 19).** Como PTP nao e necessario para uso comum, a correcao pratica mais simples e desabilitar a tentativa no DTB/driver. Implementar PTP real seria dificuldade media e nao traz beneficio para este aparelho.

#### Baixa - algumas horas, escopo localizado

4. **Arquivos ODM ausentes (problema 17).** Criar `default.prop` e `ueventd.rc` minimos, incluir no build e validar permissoes. Parte dos ajustes atualmente espalhados por vendor pode ser movida para ODM depois.
5. **Probes de hardware ausente (problemas 16 e 20).** Desabilitar nos DTBs os nos realmente inexistentes, como NAND, USB2 sem portas, page trace e recursos nao montados. Exige cuidado para nao remover um bloco usado indiretamente, mas e uma limpeza localizada.
6. **Factory reset ausente (problema 5).** Restaurar ou implementar `/system/bin/factoryreset.sh`, adicionar ao `device.mk`, definir contexto/permissoes e testar recovery/wipe. O script e simples; o risco vem de ser uma operacao destrutiva, portanto o teste deve ser feito com backup.

#### Media - um ou poucos dias, exige testes de boot

7. **Gadget USB/ADB triplicado (problema 6).** Identificar os tres gatilhos init/configfs que criam `android0`, escolher um unico proprietario e testar ADB em boot, reconexao USB e troca de funcoes. O codigo e pequeno, mas a ordem dos eventos Android USB e sensivel.
8. **`tune2fs`/`e2fsck` depois do mount (problema 4).** Mover manutencao para first-stage mount ou executar somente antes de montar `/data`. Precisa testar boot normal, filesystem sujo, reinicio forcado, quota e criptografia para nao criar loop de boot.
9. **Troca HDMI 2160p30 -> 1080p60 (problema 12).** Corrigir a fonte da selecao em `systemcontrol`/propriedades para iniciar diretamente no modo persistido ou EDID escolhido. As protecoes do kernel permanecem como fallback. Deve ser testado em TVs 720p, 1080p e 4K.
10. **Audio parcialmente descrito (problema 14).** Se somente HDMI for requisito, remover rotas analogicas inexistentes e validar volume/mute. Fazer analogico e S/PDIF realmente funcionarem exige mapear pinos e sobe para dificuldade alta.
11. **Preparar o eMMC detectado (problema 8).** A comunicacao eletrica ja funciona. E necessario gravar bootloader, MPT e particoes com offsets corretos, copiar a ROM e testar boot/readback. A dificuldade e media, mas o risco de apagar o dispositivo errado e alto.

#### Alta - varios dias, cruza kernel/vendor/framework

12. **Ambiente/DTB reservado do U-Boot (problema 15).** Criar e manter copias validas de DTB/env na estrutura Amlogic, ajustar o bootloader para SD/eMMC e garantir fallback. Interfere na logica especial de reset, cartao e TFTP, portanto exige matriz de testes.
13. **Pressao de memoria/CMA (problema 2).** Reduzir `codec_mm_cma`, ION, DI ou VDIN e relativamente simples no DTB; descobrir limites seguros nao e. Deve-se testar launcher, 1080p/4K, H.264/H.265/VP9, seek, bootanimation e captura. Reduzir demais causa falha ou travamento de video.
14. **Boot completo lento (problema 3).** Nao ha uma causa unica. Depende de corrigir auditoria SELinux, inicializacao Wi-Fi, servicos/HALs, USB, modo HDMI e carga do framework. Melhorias devem ser medidas por marco para evitar trocar tempo de boot por instabilidade.
15. **Wi-Fi SV6051P (problema 9).** Driver/firmware proprietarios antigos, sequencia de power/reset, timeouts SDIO e ciclo do `wpa_supplicant` precisam ser tratados juntos. Requer varios boots, associacao, DHCP, WPA2/WPA3, reconexao e teste simultaneo com Ethernet.
16. **HALs SystemControl e HDMI-CEC (problema 10).** Alinhar binarios, rc, manifestos VINTF, versoes 1.0/1.1 e politica SELinux. CEC ainda exige teste com televisores diferentes; o driver de kernel sozinho nao garante funcionamento Android.
17. **Recursos DTB de GE2D/PicDec/VDIN/codecs (problema 13).** Exige comparar DTB/kernel Aquario original com a base atual e portar registradores, clocks e reservas corretos. Um erro pode causar corrupcao de memoria ou quebrar a aceleracao que ja funciona.

#### Muito alta - projeto de integracao, semanas

18. **SELinux/system/vendor incompativeis (problema 1).** E necessario unificar sepolicy, tipos, `file_contexts`, `property_contexts`, `service_contexts`, rotular novamente as imagens e eliminar AVCs por dominio. So depois se pode tentar enforcing. Corrigir apenas os 126 AVCs observados nao basta, pois o audit ja suprimiu muitos outros.
19. **DRM, Widevine, defendkey, TEE e AVB (problema 11).** Exige cadeia coerente de boot verificado, TEE, chaves, HDCP, blobs proprietarios e politicas. Widevine L1 depende de provisionamento/certificacao que nao pode ser fabricado apenas compilando o kernel. ClearKey ou Widevine L3 podem ser viaveis, mas nao equivalem a certificacao oficial.

### Ordem recomendada de execucao

1. Regravar o quadro 10, definir serial e restaurar factory reset.
2. Corrigir a ordem de `fsck`/quota e remover a tripla criacao do gadget USB.
3. Corrigir a selecao HDMI e limpar DTB de hardware comprovadamente ausente.
4. Medir CMA e reduzir reservas gradualmente com testes de video.
5. Estabilizar Wi-Fi, HALs e recursos DTB restantes.
6. Unificar SELinux e somente depois avaliar enforcing.
7. Tratar DRM/TEE/AVB como projeto separado, sem bloquear a usabilidade geral do Android.

## 2026-07-30 - v65: correcoes simples e primeira reducao de memoria

- Foi mantido sem alteracao o kernel ARM64 4.9.113 v62 `#24`, SHA256 `159a51a2a60c485ad4237b1b3ecab6c505cc19b7ebe98cfa7e246d31da20bd6b`. A v65 altera somente ramdisk, DTB e cmdline.
- Imagem gravada no boot do cartao: `work/boot-performance-v65-20260730/boot-aquario-performance-v65-padded-16m.img`, SHA256 `97f8d697175158e511fde61eafab9d18c07f56d5171eb73c81b474082d9d1cd7`.
- A transferencia TFTP de 16 MiB para `0x1080000` e o readback do setor de boot `0x2ae000` produziram o mesmo CRC32 `147d1ff1`.
- A reserva `codec_mm_cma` foi reduzida experimentalmente de 208 para 192 MiB. VDIN0, VDIN1 e PicDec, hardware inexistente nesta placa, foram desabilitados; a reserva VDIN1 efetiva de 16 MiB foi removida. Total devolvido nessa revisao: 32 MiB.
- No primeiro boot v65 o mapa confirmou `codec_mm_cma=196608 KiB`; depois do Android completo, `/proc/meminfo` informou `MemTotal=1009712 KiB`, `MemAvailable=305736 KiB`, `CmaTotal=323584 KiB` e zram de 262140 KiB. A base anterior tinha `CmaTotal=356352 KiB` no boot analisado.
- A cmdline passou a usar `audit=0`, `loglevel=4`, sem `ignore_loglevel` nem `keep_bootcon`. O serial Android ficou estavel como `210bc2004e90bd1545c223aedae47e13`.
- Foram adicionados `/odm/default.prop` e `/odm/ueventd.rc` minimos ao device tree AOSP, ao ramdisk ativo e ao aparelho, com `root:root`, modo 0644 e contexto `vendor_file`.
- Os imports repetidos de `init.amlogic.usb.rc` foram removidos de `init.amlogic.board.rc` e `init.amlogic.wifi.rc`; o arquivo principal continua sendo o unico proprietario do import. O objetivo e reduzir as tres tentativas concorrentes de criar `android0`.
- O monitor de CPU/RAM/GPU passou de atualizacao a cada 2 s para 5 s e deixou de executar `chmod` em todo ciclo. Isso reduz wakeups e processos curtos sem remover as metricas do launcher.
- O bloco U-Boot do quadro 10 foi regravado no setor `0x29a000`; o readback passou a coincidir com o esperado, SHA256 `839ebc073fc7aa49c8f700acb0ae53299376ea9e0f5166eb9e81ebc8e31bc015`.
- Uma tentativa de implementar factory reset revelou que o framework envia `ctl.start factoryreset` durante todo boot. O script experimental escrevia `--wipe_data` e causou loop de reboot, embora o U-Boot desta placa nao tenha entrado no recovery e `/data` nao tenha sido apagada. A solucao segura na v65 foi remover totalmente o servico e o script ate entender e corrigir o contrato do framework/recovery.
- O resíduo `/system/bin/factoryreset.sh` foi removido tanto do Android em execucao quanto de `scratch/permanent-20260730/system-permanent.img`. A imagem ext4 passou por `e2fsck`; novo SHA256: `3d6d4454b33aff31ffbcf712fee14732cb3e58d126f70fa65d52f9eee086d11b`.
- Primeiro boot v65 via `bootm 0x1080000`: `sys.boot_completed=1`, sem servico `factoryreset` e sem reinicializacao depois de mais de um minuto. Ainda falta a rodada de regressao por reboot/autoboot normal, playback de video e inspecao do log completo.

## 2026-07-30 - v66/v67: USB limpo e carga de fundo reduzida

- A causa da tentativa restante de criar `android0` era o uso simultaneo do gadget ConfigFS do Android 9 e do `init.amlogic.usb.rc` legado. O HAL moderno terminou com `sys.usb.configfs=1`, mas o arquivo Amlogic esperava `dev.bootcomplete=1`, reinseria `dwc3.ko` e tentava registrar o gadget legado.
- Na v66 o import de `init.amlogic.usb.rc` foi removido de `init.amlogic.rc`. O USB padrao permaneceu em ConfigFS, `sys.usb.state=adb` e `adbd=running`. No log completo desapareceram `android0 -EEXIST` e `WARNING: CPU`; o restart posterior do `adbd` permanece e pertence ao postboot que habilita ADB TCP.
- A medicao logo apos o boot mostrou que Globoplay, Prime Video e Aurora Store ficavam residentes sem terem sido abertos. Em uma amostra inicial houve `275%` de I/O wait, `kswapd0` ativo e processos dos tres aplicativos.
- A v67 executa `am force-stop` nesses tres pacotes ao terminar o boot. Eles continuam instalados e o Android remove o estado stopped quando o usuario abre o app, mas nao permanecem residentes no launcher. YouTube e seu agendador de recomendacoes nao foram alterados.
- Imagem v67 instalada: `work/boot-performance-v67-20260730/boot-aquario-performance-v67-padded-16m.img`, SHA256 `e5ca8548d595cab746b2aad16cbb525e30a02358d2c78326970643e8389005a3`. O readback de `/dev/block/boot` foi identico. Copia TFTP: `work/aquario-rescue-initramfs-v35/boot-aquario-v67.img`, mesmo SHA256.
- Boot de regressao: `logs/boot-captures/v67-performance-final-20260730`, `sys.boot_completed=1`, recorte deduplicado SHA256 `ae7e7a3d702a600aa7282bab1bee252cc2a566f19d382905f2a45ff5f2d80d10`.
- No log v67 nao houve `WARNING: CPU`, `android0 -EEXIST`, `audit: rate limit exceeded`, factory reset, ODM ausente, panic, OOM ou erro EXT4. O kernel permaneceu 4.9.113 `#24` e `codec_mm_cma=196608 KiB`.
- A carga de armazenamento ainda e muito alta nos primeiros minutos por framework/GApps/Play Store no cartao: aos dois minutos houve uma amostra de `331%` de I/O wait mesmo com os tres apps opcionais ausentes. Aos quatro minutos a atividade assentou em `0%` de I/O wait, 374/400% de CPU ociosa, `MemAvailable=276200 KiB`, e o monitor informou `CPU 1%`, `RAM 716 MB usada / 270 MB livre`, `GPU 0%`. Portanto o force-stop reduz residentes, mas nao elimina o custo estrutural do Android/GApps sobre SD.
- Validacao inicial de CMA e codecs pelo VLC:
  - H.264 1920x1080, 60 fps, 20 Mbps abriu `OMX.amlogic.avc.decoder.awesome`;
  - HEVC 1920x1080, 60 fps, 10 Mbps abriu `OMX.amlogic.hevc.decoder.awesome` e chegou a `OMX_StateExecuting`;
  - HEVC 3840x2160, 30 fps, 20 Mbps tambem abriu o decoder de hardware e chegou a `OMX_StateExecuting`.
- Os erros OMX `UnsupportedSetting`/`BadPortIndex` durante negociacao de buffers continuam sendo tratados pelo fallback do codec. O teste 4K posterior revelou tambem repetidos erros `SCATTER_MEM` com 192 MiB; por isso a v67 nao deve ser considerada a configuracao CMA final.
- O aviso U-Boot `There is no valid bmp file at the given address` ainda ocorre imediatamente depois de ler o setor do quadro 10, embora o bloco gravado e seu readback tenham SHA256 correto. Isso indica incompatibilidade de formato/estado do comando BMP, nao nova corrupcao do cartao. E um problema visual separado, sem impacto no boot ou desempenho do Android.

## 2026-07-30 - v69 final: CMA equilibrado para 4K

- O teste prolongado mostrou que 192 MiB de `codec_mm_cma` da v67 produziam repetidos `not enough mem for SCATTER_MEM` durante HEVC 4K. A v68 restaurou os 208 MiB originais, mas o limite continuou. Isso provou que a reserva original tambem era curta para esse caso e que manter 192 MiB pioraria a margem.
- A reserva VDIN1 removida tinha 16 MiB efetivos, nao 32 MiB. Na v69 esses 16 MiB foram integralmente realocados ao codec: `codec_mm_cma=229376 KiB` (224 MiB). O `CmaTotal=356352 KiB` ficou igual ao da imagem original analisada, portanto nao houve aumento da reserva total nem perda adicional de RAM geral.
- No mesmo arquivo HEVC 3840x2160, 30 fps, 20 Mbps, o decoder `OMX.amlogic.hevc.decoder.awesome` abriu via MediaCodec e chegou a `OMX_StateExecuting`. Os avisos de scatter cairam para oito ocorrencias iniciais, em vez do fluxo continuo observado com 192/208 MiB. Nao foram eliminados completamente; resolver o restante exigiria aumentar CMA acima do total original ou corrigir o alocador/codec legado.
- Imagem final instalada no cartao: `work/boot-performance-v69-20260730/boot-aquario-performance-v69-padded-16m.img`, SHA256 `32bb8014eda730f37a3cc756a9b330cedb236e326b12241c6737c16327ebc39e`. Readback de `/dev/block/boot` identico.
- Copia para recuperacao TFTP: `work/aquario-rescue-initramfs-v35/boot-aquario-v69.img`, mesmo SHA256.
- Boot completo: `logs/boot-captures/v69-codec-224m-20260730`, `sys.boot_completed=1`; log deduplicado SHA256 `52270c26826d6be029054d000c05c8e4373df74dfd87882a080cc4baf3eb8735`.
- O boot v69 nao apresentou `WARNING: CPU`, `android0 -EEXIST`, flood `audit: rate limit exceeded`, factory reset, panic, OOM ou erro EXT4. O aviso BMP do quadro 10 continua sendo a unica regressao visual conhecida nessa lista de correcoes faceis.
- Estado apos os testes: VLC encerrado, arquivos de video temporarios removidos, launcher reaberto, Prime Video/Globoplay/Aurora fora da memoria, `MemAvailable=275908 KiB`, monitor `CPU 8%`, `RAM 720 MB usada / 266 MB livre`, `GPU 0%`.
# 2026-07-31 - Standby, Power e LEDs (investigacao v69 -> v70)

- O controle Aquario usa NEC custom code `0x4040`; Power e o scancode `0x4d`,
  mapeado no DTB para Linux `KEY_POWER` (`116`). O keylayout Android tambem
  possui `key 116 POWER`.
- A policy do Android esta correta:
  `SHORT_PRESS_POWER_GO_TO_SLEEP`. Um evento limpo de Power muda
  `mWakefulness` para `Asleep`; portanto o defeito nao e o mapeamento da tecla.
- `stay_on_while_plugged_in` estava em `1` e `mStayOn=true` por causa da fonte
  dummy. Isso nao impede o Power explicito, mas foi corrigido permanentemente
  para `0` nos dois postboot sources.
- O primeiro teste mostrou repeticoes de suspend e alguns
  `alarmtimer ... returns -16`. Com console loglevel 8 foi possivel ver que os
  alarmes curtos apenas adiam algumas tentativas; eles nao sao a causa raiz.
- A tentativa limpa chega a suspender todos os devices, desliga CPU1/2/3 e
  entra em `gxbb_pm: enter meson_pm_suspend!`, mas
  `arm_cpuidle_suspend()` retorna em 0,002 s sem wake IRQ real. O estado atual
  do DTB era `arm,psci-suspend-param = <0x20000>`.
- O firmware do U-Boot Aquario anuncia PSCI 0.2, mas nao sustenta esse estado
  GXL vendor. A v70 testa o estado PSCI power-down padrao `0x10000`; os devices
  e CPUs secundarias ja estao suspensos quando ele e invocado.
- O DTB v69 tinha `/sysled status="disabled"`. O DTB original Aquario usa o
  mesmo GPIO 73, active-low, com `status="okay"`. A v70 habilita `sysled`; o
  driver `led_sys` liga o azul em probe/resume e o desliga em
  suspend/shutdown, permitindo o vermelho de standby da placa.
- O driver CEC procura um estado pinctrl chamado `cec_pin_sleep`, mas o DTB
  importado so declarava `default`, gerando `pinctrl sleep_state error`. A v70
  nomeia tambem `cec_pin_sleep` usando o mesmo pin AO do estado ativo.
- Parar os HALs CEC nao e aceitavel: o `system_server` fica bloqueado tentando
  reconectar ao vendor HAL. Os servicos CEC devem permanecer ativos.
- O coletor Aquario de CPU/RAM/GPU com `sleep 5` foi testado parado. Ele nao e
  a causa raiz do retorno imediato de PSCI e deve continuar disponivel.
# 2026-07-31 - Identificacao fisica do LED bicolor

- O LED frontal foi confirmado no `GPIODV_24`, indice DT `73`, GPIO global
  `474` no kernel 4.9.
- Testes estaticos iniciais sob a v70 pareceram nao produzir efeito porque o
  `sysled` mantinha o GPIO requisitado e reprogramava seu estado.
- Apos reboot para o boot permanente sem o `sysled` ativo, um teste alternando
  o GPIO 474 a cada 500 ms fez o LED vermelho acender. Portanto o pino e a
  ligacao fisica estao confirmados; falta determinar a polaridade exata
  vermelho/azul e torna-la permanente no driver/DT.
- `GPIODV_27` (GPIO 477) e `GPIOAO_3..5` (GPIO 504..506) nao alteraram o LED.
- Um teste em grupo iniciado em `GPIODV_0` derrubou/reiniciou o aparelho; nao
  repetir varredura ampla. O GPIO 450 deve ser tratado como critico ate
  investigacao posterior.
- Polaridade observada no boot permanente sem o driver `sysled` requisando o
  pino: GPIO 474 em nivel baixo acende vermelho; nivel alto apaga; como entrada
  o pino e puxado para baixo e tambem acende vermelho.
- O azul nao e uma segunda saida descrita no DT original. Testes em
  `GPIOH_3`, `GPIOZ_14/Z_15`, `GPIODV_27` e `GPIOAO_3..5/6/9` nao acenderam
  azul.
- A fonte oficial do U-Boot `gxl_p281_v1` inicializa o LED limpando o pinmux de
  `GPIODV_24`, configurando o bit 24 de `PREG_PAD_GPIO0_EN_N` como saida e
  colocando o bit 24 de `PREG_PAD_GPIO0_O` em 1. Isso confirma DV24 como a
  unica linha de LED conhecida; a cor azul provavelmente depende do estado
  eletrico/rail estabelecido no power-on.
- `GPIODV_25` (GPIO 475) provoca reboot/perda imediata do aparelho quando
  forcado como saida; nao testar novamente. O DT mostra DV24/DV25 com funcoes
  alternativas UART B e I2C A.
- Varredura U-Boot com o vermelho desligado (`GPIODV_24=1`) nao encontrou o
  azul em nivel baixo nos seguintes grupos: `GPIODV_1..23`, `GPIODV_26..29`,
  `GPIOAO_3..9`, `GPIOH_0..9`, `GPIOZ_0..15`, `GPIOX_0..18`,
  `GPIOCLK_0..1` e `BOOT_0..15`. Os pinos foram devolvidos para entrada
  depois de cada grupo. `CARD_0..6` nao foram alterados porque hospedam o
  cartao SD em uso.
- A leitura direta no U-Boot confirmou o pinmux DV24 livre
  (`c88344b0..c88344bc`: somente mux2 `0x00001800`, referente a DV28/DV29).
  O banco GPIO mostrou `EN_N=0xfeffffff` e `OUT=0xdb000001`: DV24 e realmente
  uma saida em nivel alto, nao apenas um valor virtual do comando `gpio set`.
- O driver original `drivers/amlogic/led/led_sys.c` nao consulta a propriedade
  separada `led_active_low`; ele usa somente a flag da celula `led_gpio`.
  Como o DTB Aquario original declara flags `0`, o comportamento efetivo e:
  brilho ligado/probe/resume -> DV24 alto; desligado/suspend/shutdown -> DV24
  baixo. Isso casa com a intencao do firmware de alternar azul em execucao e
  vermelho em standby usando uma unica linha logica.
- O Android v69, cujo `/sysled` permanece desabilitado, completou o boot com
  DV24 nao requisitado. O regmap debugfs continuou exatamente igual ao
  U-Boot (`EN_N=0xfeffffff`, `OUT=0xdb000001`, pinmux sem funcao): DV24 ficou
  como saida alta durante toda a transicao, mas o usuario ainda nao observou
  azul. Portanto ha uma dependencia eletrica/controlador adicional ou falha
  fisica do canal azul; nao e falta de escrever nivel alto no DV24.
- A mensagem `board_init sm1628` pertence ao BL33 Aquario. SM1628/TM1628 e um
  controlador externo de matriz de LEDs compativel com SPI de tres fios; o
  DTS de referencia associa SCK a DV27, MOSI a DV26 e CS ativo-baixo a AO4.
  A hipotese foi testada novamente no Android com um transmissor ARM nativo,
  protocolo LSB-first, modo SM1628C, todos os 14 bytes em `0xff`, display
  ligado e brilho maximo (`0x8f`). A transmissao por DV26/DV27/AO4 concluiu,
  mas nao acendeu azul. Os tres GPIOs foram depois liberados. Portanto o
  SM1628 nao controla o canal azul deste LED frontal.
