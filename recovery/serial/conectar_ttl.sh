#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_env
kernel_baud="${SERIAL_BAUD_RATE:-115200}"
boot_baud="${SERIAL_BOOT_BAUD_RATE:-$kernel_baud}"
broker_port="${SERIAL_BROKER_PORT:-31337}"
broker_image="${SERIAL_BROKER_IMAGE:-recovery-lab-serial-terminal:latest}"
tx_byte_delay="${SERIAL_TX_BYTE_DELAY:-0}"
serial_device_override=""
reset_broker=0
show_status=0
probe_serial=0

require_command python3
require_command nc
require_command docker
mkdir -p "$SCRIPT_DIR/logs"

usage() {
	cat <<EOF
Uso: $0 [opcoes]

Opcoes:
  --device CAMINHO   Usa um adaptador serial especifico.
  --boot-baud TAXA    Baud inicial usado pelo bootloader.
  --kernel-baud TAXA  Baud usado depois que o kernel inicia.
  --tx-byte-delay S   Intervalo em segundos entre bytes transmitidos.
  --reset            Para o broker atual antes de conectar.
  --status           Mostra o broker/dispositivo atual e sai.
  --probe            Testa leitura serial por alguns segundos e sai.
  -h, --help         Mostra esta ajuda.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--device)
			serial_device_override="${2:-}"
			[[ -n "$serial_device_override" ]] || {
				echo "--device precisa de um caminho." >&2
				exit 1
			}
			shift 2
			;;
		--boot-baud)
			boot_baud="${2:-}"
			shift 2
			;;
		--kernel-baud)
			kernel_baud="${2:-}"
			shift 2
			;;
		--tx-byte-delay)
			tx_byte_delay="${2:-}"
			shift 2
			;;
		--reset)
			reset_broker=1
			shift
			;;
		--status)
			show_status=1
			shift
			;;
		--probe)
			probe_serial=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Opcao desconhecida: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

for rate_name in boot_baud kernel_baud; do
	rate="${!rate_name}"
	if [[ ! "$rate" =~ ^[1-9][0-9]*$ ]]; then
		printf '%s precisa ser uma taxa numerica positiva: %s\n' \
			"$rate_name" "$rate" >&2
		exit 1
	fi
done

detect_serial_device() {
	local candidate
	local active_pid=""
	local active_device=""

	if [[ -z "${serial_device_override:-}" ]]; then
		active_pid="$(broker_pid_for_port || true)"
		active_device="$(broker_device_for_pid "$active_pid" || true)"
		if [[ -n "$active_device" && -e "$active_device" ]]; then
			readlink -f "$active_device"
			return 0
		fi
	fi

	for candidate in \
		${serial_device_override:-} \
		${SERIAL_DEVICE:-} \
		/dev/serial/by-id/*USB_UART* \
		/dev/serial/by-id/*UART* \
		/dev/ttyUSB* \
		/dev/ttyACM*
	do
		[[ -e "$candidate" ]] || continue
		readlink -f "$candidate"
		return 0
	done

	return 1
}

broker_pid_for_port() {
	ps -eo pid=,args= \
		| awk -v port="$broker_port" '
			/serial_broker.py broker/ && $0 ~ "--port " port {
				print $1
				exit
			}'
}

broker_device_for_pid() {
	local pid="$1"
	local args device

	[[ -n "$pid" ]] || return 1
	args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
	[[ -n "$args" ]] || return 1

	device="$(awk '
		{
			for (i = 1; i <= NF; i++) {
				if ($i == "--device" && (i + 1) <= NF) {
					print $(i + 1)
					exit
				}
			}
		}' <<<"$args")"
	[[ -n "$device" ]] || return 1
	readlink -f "$device" 2>/dev/null || printf '%s\n' "$device"
}

broker_arg_for_pid() {
	local pid="$1"
	local option="$2"
	local args

	[[ -n "$pid" ]] || return 1
	args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
	[[ -n "$args" ]] || return 1

	awk -v option="$option" '
		{
			for (i = 1; i <= NF; i++) {
				if ($i == option && (i + 1) <= NF) {
					print $(i + 1)
					exit
				}
			}
		}' <<<"$args"
}

stop_broker_for_port() {
	local pid
	local attempts=0

	docker rm -f serial_ttyUSB0 serial_ttyUSB1 serial_ttyACM0 serial_ttyACM1 \
		recovery-lab-serial-terminal-1 router_ttl_terminal \
		>/dev/null 2>&1 || true

	while pid="$(broker_pid_for_port)" && [[ -n "$pid" ]]; do
		kill "$pid" >/dev/null 2>&1 || true
		attempts=$((attempts + 1))
		if [[ "$attempts" -ge 15 ]]; then
			printf 'Nao consegui parar o broker pid=%s sem privilegios. ' "$pid" >&2
			printf 'Feche o terminal/container que segura a serial e tente de novo.\n' >&2
			return 1
		fi
		sleep 0.2
	done
}

device="$(detect_serial_device || true)"
if [[ -z "$device" ]]; then
	echo "Nenhum adaptador serial encontrado." >&2
	echo "Verifique o cabo TTL ou configure SERIAL_DEVICE em .env." >&2
	echo "Candidatos esperados: /dev/serial/by-id/*, /dev/ttyUSB*, /dev/ttyACM*" >&2
	exit 1
fi

device="$(readlink -f "$device")"
session_name="serial_${device##*/}"
log_name="${session_name}.log"
broker_pid="$(broker_pid_for_port || true)"
broker_device="$(broker_device_for_pid "$broker_pid" || true)"
broker_boot_baud="$(broker_arg_for_pid "$broker_pid" --baud || true)"
broker_kernel_baud="$(broker_arg_for_pid "$broker_pid" --switch-baud || true)"
expected_switch_baud=""
broker_switch_args=()
if [[ "$boot_baud" != "$kernel_baud" ]]; then
	expected_switch_baud="$kernel_baud"
	broker_switch_args=(--switch-baud "$kernel_baud" --switch-on-garble)
fi

if [[ "$show_status" -eq 1 ]]; then
	printf 'Dispositivo detectado: %s\n' "$device"
	if [[ -n "$broker_pid" ]]; then
		printf 'Broker ativo: pid=%s device=%s port=%s boot_baud=%s kernel_baud=%s\n' \
			"$broker_pid" "${broker_device:-desconhecido}" "$broker_port" \
			"${broker_boot_baud:-desconhecido}" "${broker_kernel_baud:-sem troca}"
	else
		printf 'Broker ativo: nenhum na porta %s\n' "$broker_port"
	fi
	docker ps --filter "name=serial_" --format 'Container: {{.Names}} {{.Status}} {{.Image}}'
	exit 0
fi

if [[ "$reset_broker" -eq 1 ]]; then
	stop_broker_for_port
	broker_pid=""
	broker_device=""
fi

if [[ -n "$broker_pid" ]] && {
	[[ "$broker_device" != "$device" ]] \
		|| [[ "$broker_boot_baud" != "$boot_baud" ]] \
		|| [[ "$broker_kernel_baud" != "$expected_switch_baud" ]]
}; then
	printf 'Broker atual nao corresponde a device/baud solicitados; reiniciando.\n' >&2
	stop_broker_for_port
	broker_pid=""
	broker_device=""
fi

if [[ "$boot_baud" == "$kernel_baud" ]]; then
	printf 'Conectando em %s a %s bps. Log: logs/%s\n' \
		"$device" "$kernel_baud" "$log_name"
else
	printf 'Conectando em %s: bootloader=%s bps, kernel=%s bps (troca automatica). Log: logs/%s\n' \
		"$device" "$boot_baud" "$kernel_baud" "$log_name"
fi

if ! nc -z 127.0.0.1 "$broker_port" >/dev/null 2>&1; then
	if [[ -w "$device" ]]; then
		nohup python3 "$SCRIPT_DIR/lib/serial_broker.py" broker \
			--device "$device" \
			--baud "$boot_baud" \
			"${broker_switch_args[@]}" \
			--host 127.0.0.1 \
			--port "$broker_port" \
			--tx-byte-delay "$tx_byte_delay" \
			--log "$SCRIPT_DIR/logs/$log_name" \
			>"$SCRIPT_DIR/logs/${session_name}.broker.log" 2>&1 &
	else
		docker rm -f "$session_name" >/dev/null 2>&1 || true
		if ! docker image inspect "$broker_image" >/dev/null 2>&1 \
			|| ! docker run --rm "$broker_image" python3 --version >/dev/null 2>&1; then
			compose build serial-terminal >>"$SCRIPT_DIR/logs/${session_name}.broker.log" 2>&1
		fi
		nohup docker run -d \
			--name "$session_name" \
			--network host \
			--device "$device:$device" \
			-v "$SCRIPT_DIR:$SCRIPT_DIR" \
			-w "$SCRIPT_DIR" \
			"$broker_image" \
			python3 lib/serial_broker.py broker \
				--device "$device" \
				--baud "$boot_baud" \
				"${broker_switch_args[@]}" \
				--host 127.0.0.1 \
				--port "$broker_port" \
				--tx-byte-delay "$tx_byte_delay" \
				--log "$SCRIPT_DIR/logs/$log_name" \
			>"$SCRIPT_DIR/logs/${session_name}.broker.log" 2>&1 &
	fi

	for _ in $(seq 1 50); do
		nc -z 127.0.0.1 "$broker_port" >/dev/null 2>&1 && break
		sleep 0.1
	done
fi

if ! nc -z 127.0.0.1 "$broker_port" >/dev/null 2>&1; then
	echo "Falha ao iniciar o broker serial. Veja: $SCRIPT_DIR/logs/${session_name}.broker.log" >&2
	if [[ -f "$SCRIPT_DIR/logs/${session_name}.broker.log" ]]; then
		tail -n 20 "$SCRIPT_DIR/logs/${session_name}.broker.log" >&2 || true
	fi
	exit 1
fi

if [[ "$probe_serial" -eq 1 ]]; then
	printf 'Testando leitura da serial por 5 segundos...\n' >&2
	if python3 - "$broker_port" <<'PY'
import select
import socket
import sys
import time

port = int(sys.argv[1])
with socket.create_connection(("127.0.0.1", port), timeout=3) as sock:
    sock.setblocking(False)
    end = time.monotonic() + 5
    while time.monotonic() < end:
        ready, _, _ = select.select([sock], [], [], 0.5)
        if not ready:
            continue
        data = sock.recv(4096)
        if data:
            sys.exit(0)
sys.exit(1)
PY
	then
		printf 'Serial recebeu dados.\n'
	else
		printf 'Nenhum dado novo recebido da serial em 5 segundos.\n' >&2
		printf 'O broker esta ativo; verifique se o roteador esta emitindo log ou reinicie/pressione Enter no console.\n' >&2
		exit 1
	fi
	exit 0
fi

exec python3 "$SCRIPT_DIR/lib/serial_broker.py" client \
	--host 127.0.0.1 \
	--port "$broker_port"
