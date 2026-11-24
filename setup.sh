#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

networks=(
    tyr-infra-net-proxy
    tyr-prod-net-proxy
    tyr-prod-net-infrastructure
    tyr-prod-net-administration
    tyr-dev-net-proxy
    tyr-dev-net-infrastructure
    tyr-dev-net-administration
)

# Docker offset for users.
OFF=$(awk -F: '$1=="dockremap"{print $2}' /etc/subuid)
OFF=${OFF:-0}

mk() { install -d -m 0700 -o $((OFF + $2)) -g $((OFF + $2)) "$1"; }
ensure_net() {
    local name=$1; shift
    docker network inspect "$name" &>/dev/null || docker network create "$@" "$name" >/dev/null
}

# Real root, not remapped.
install -d -m 0700 -o root -g root /data

case "${1:-}" in
    prod)
        mk /data/caddy/data 0
        mk /data/caddy/config 0
        mk /data/tyr/prod/infra/cache 999

        for n in "${networks[@]}"; do
            ensure_net "$n" --driver overlay --internal --opt com.docker.network.driver.mtu=1370
        done
        ensure_net "typingrealm" --driver overlay --attachable --internal --opt com.docker.network.driver.mtu=1370
        ;;
    dev)
        mk /data/tyr/infra/seq 0
        mk /data/tyr/infra/pgadmin 5050
        mk /data/tyr/infra/redisinsight 1000
        mk /data/tyr/dev/infra/cache 999
        ;;
    *) echo "usage: $0 prod|dev" >&2; exit 1 ;;
esac

echo "Done!"
