#!/usr/bin/env bash

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

load_env() {
	if [[ -f "$PROJECT_DIR/.env" ]]; then
		set -a
		# shellcheck disable=SC1091
		. "$PROJECT_DIR/.env"
		set +a
	fi
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'Comando necessário não encontrado: %s\n' "$1" >&2
		exit 1
	fi
}

normalize_iface() {
	local iface="$1"
	if [[ -z "$iface" ]]; then
		return 0
	fi

	printf '%s' "$iface"
}

detect_gateway_for_iface() {
	local iface="$1"
	ip route show dev "$iface" default 2>/dev/null | awk '/^default / { print $3; exit }'
}

iface_has_ipv4() {
	local iface="$1"
	ip -4 addr show dev "$iface" 2>/dev/null | grep -q 'inet '
}

remove_static_address_from_other_ifaces() {
	local keep_iface="$1"
	local address="$2"
	local host="${address%/*}"
	local iface

	[[ -n "$keep_iface" ]] || return 0
	[[ -n "$host" ]] || return 0

	while read -r iface; do
		[[ -n "$iface" ]] || continue
		[[ "$iface" == "$keep_iface" ]] && continue

		if command -v nmcli >/dev/null 2>&1; then
			nmcli con down "tftp-${iface}" >/dev/null 2>&1 || true
			nmcli con delete "tftp-${iface}" >/dev/null 2>&1 || true
		fi

		run_root ip address del "$address" dev "$iface" 2>/dev/null || true
	done < <(ip -o -4 addr show | awk -v host="$host" '$4 ~ "^" host "/" { print $2 }')
}

lease_dhcp_on_iface() {
	local iface="$1"

	[[ -n "$iface" ]] || return 0
	require_command ip

	if iface_has_ipv4 "$iface"; then
		return 0
	fi

	if command -v nmcli >/dev/null 2>&1; then
		nmcli device connect "$iface" >/dev/null 2>&1 || true
		if iface_has_ipv4 "$iface"; then
			return 0
		fi
	fi

	run_root ip link set "$iface" up

	if command -v dhclient >/dev/null 2>&1; then
		run_root dhclient -4 -v -1 "$iface" || true
		if iface_has_ipv4 "$iface"; then
			return 0
		fi
	fi

	if command -v udhcpc >/dev/null 2>&1; then
		run_root udhcpc -i "$iface" -n -q || true
		if iface_has_ipv4 "$iface"; then
			return 0
		fi
	fi

	printf 'Nenhum cliente DHCP encontrado (dhclient/udhcpc).\n' >&2
	return 1
}

configure_static_iface() {
	local iface="$1"
	local address="$2"
	local connection="tftp-${iface}"

	[[ -n "$iface" ]] || return 0
	[[ -n "$address" ]] || return 0

	require_command ip
	if ! ip link show dev "$iface" >/dev/null 2>&1; then
		printf 'Interface não encontrada: %s\n' "$iface" >&2
		exit 1
	fi

	remove_static_address_from_other_ifaces "$iface" "$address"

	if ! ip address show dev "$iface" | grep -Fq "inet ${address%/*}/"; then
		if command -v nmcli >/dev/null 2>&1; then
			if nmcli con show "$connection" >/dev/null 2>&1; then
				nmcli con modify "$connection" \
					ifname "$iface" \
					ipv4.method manual \
					ipv4.addresses "$address" \
					ipv6.method disabled >/dev/null
			else
				nmcli con add type ethernet \
					ifname "$iface" \
					con-name "$connection" \
					ipv4.method manual \
					ipv4.addresses "$address" \
					ipv6.method disabled >/dev/null
			fi
			nmcli con up "$connection" >/dev/null 2>&1 || true
		fi
	fi

	if ! ip address show dev "$iface" | grep -Fq "inet ${address%/*}/"; then
		run_root ip address add "$address" dev "$iface"
	fi

	if ! ip link show dev "$iface" | grep -Fq 'UP'; then
		if command -v nmcli >/dev/null 2>&1; then
			nmcli device connect "$iface" >/dev/null 2>&1 || true
		fi
		if ! ip link show dev "$iface" | grep -Fq 'UP'; then
			run_root ip link set "$iface" up
		fi
	fi
}

compose() {
	docker compose --project-directory "$PROJECT_DIR" "$@"
}

ensure_service() {
	local service="$1"
	local container="$2"

	if [[ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" != "true" ]]; then
		compose up -d "$service"
	fi
}

run_root() {
	if [[ "$EUID" -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

ensure_router_wifi() {
	local active_connection

	[[ -n "${WIFI_SSID:-}" ]] || return 0
	require_command nmcli

	active_connection="$(nmcli -t -f active,ssid dev wifi 2>/dev/null \
		| awk -F: '$1 == "yes" { print $2; exit }')"
	[[ "$active_connection" == "$WIFI_SSID" ]] && return 0

	if [[ -n "${WIFI_PASSWORD:-}" ]]; then
		nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD"
	else
		nmcli device wifi connect "$WIFI_SSID"
	fi
}

maybe_discover_openwrt_host() {
	local iface="${1:-}"
	local gateway=""

	if [[ -n "${OPENWRT_HOST:-}" ]]; then
		return 0
	fi

	if [[ -n "$iface" ]]; then
		gateway="$(detect_gateway_for_iface "$iface" || true)"
	fi

	if [[ -n "$gateway" ]]; then
		export OPENWRT_HOST="$gateway"
	fi
}
