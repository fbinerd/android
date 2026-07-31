# Prebuilts & Base Partition Images (Aquário STV3000 v69/v70)

Esta pasta contém as imagens de base testadas para gerar a compilação **100% funcional e equivalente à v69/v70**:

- `boot-aquario-performance-v69-padded-16m.img`: Imagem de boot alinhada de 16MB com Kernel 4.9.113 #24, DTB v69 e ramdisk sem auditoria SELinux.
- `aquario-performance-v69.dtb`: Device Tree compilado com reserva CMA de 224MB (`codec_mm_cma=229376 KiB`), pino do LED `GPIODV_24` (GPIO 474) e sem VDIN.
- `system-permanent.img`: Partição `/system` expandida de 1.7GB contendo os aplicativos integrados (SmartTube, Aurora Store, VLC, Globoplay) e daemons de otimização de RAM.
