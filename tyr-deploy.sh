#!/usr/bin/env bash
# tyr-deploy <project> <prod|dev> [commit] [--restart]
# Deploys /data/tyr/<env>/<project>/repo at the given commit (default: the commit deployed last).
# stack.yml in the repo root = swarm stack; otherwise compose.yml = plain compose (legacy).
set -euo pipefail
die() { echo "tyr-deploy: $*" >&2; exit 1; }

project=${1:-} env=${2:-} commit=${3:-} flag=${4:-}
[[ $commit == --restart ]] && { commit=; flag=--restart; }
[[ $project =~ ^[a-z0-9-]+$ ]] || die "usage: tyr-deploy <project> <prod|dev> [commit] [--restart]"
[[ -z $flag || $flag == --restart ]] || die "unknown option $flag"
case $env in prod) branch=main ;; dev) branch=develop ;; *) die "environment must be prod or dev" ;; esac

dir=/data/tyr/$env/$project
[[ -d $dir/repo ]] || die "no repo at $dir/repo"
[[ -n $commit ]] || commit=$(cat "$dir/.deployed" 2>/dev/null) || die "nothing deployed yet, give a commit"
[[ $commit =~ ^[0-9a-f]{40}$ ]] || die "commit must be the full 40-character id"

cd "$dir/repo"
git fetch -q origin
git merge-base --is-ancestor "$commit" "origin/$branch" || die "$commit is not on $branch"
git checkout -q --detach "$commit"

export TAG=sha-$branch-$commit ENV=$env
name=tyr-$env-$project
if [[ -f stack.yml ]]; then
    die "stack mode is not implemented yet"
else
    docker compose -p "$name" -f compose.yml pull
    docker compose -p "$name" -f compose.yml up -d --remove-orphans ${flag:+--force-recreate}
fi

echo "$commit" > "$dir/.deployed"
echo "tyr-deploy: $project $env is at $commit"
