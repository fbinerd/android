FROM ubuntu:24.04 AS recovery-tools

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		arping \
		ca-certificates \
		dnsmasq \
		ethtool \
		file \
		iproute2 \
		iputils-ping \
		netcat-openbsd \
		openssh-client \
		rsync \
		socat \
		tcpdump \
	&& rm -rf /var/lib/apt/lists/*

FROM recovery-tools AS serial-terminal

RUN apt-get update \
	&& apt-get install -y --no-install-recommends picocom python3 \
	&& rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]

FROM recovery-tools AS analysis-tools

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		binutils \
		device-tree-compiler \
		libubootenv-tool \
		lz4 \
		mtd-utils \
		p7zip-full \
		python3 \
		squashfs-tools \
		u-boot-tools \
		xxd \
		xz-utils \
		zstd \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["sleep", "infinity"]

FROM recovery-tools AS tftp-server

CMD ["dnsmasq", "--no-daemon", "--port=0", "--enable-tftp", \
	"--tftp-root=/var/tftpboot", \
	"--log-facility=-"]
