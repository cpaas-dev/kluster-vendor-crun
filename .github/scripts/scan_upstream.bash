#!/usr/bin/env bash

# 扫描上游 crun 仓库，找出本仓库还没发布的版本。
# 只看上游最近 N 个正式 release，逐个检查本仓库有没有对应的 Release。
#
# 注意：crun 上游 tag 不带 v 前缀（1.29.1），本仓库的 Release 统一带 v（v1.29.1），
# 所以比对之前要先补上 v。
#
# 用法：scan_upstream.bash
#
# 环境变量：
#   TRACKED_RELEASES  跟踪上游最近多少个正式 release；默认 5
#   UPSTREAM_REPO     上游仓库；默认 containers/crun
#   GH_TOKEN          gh CLI 凭据
#   GH_REPO           本仓库 cpaas-dev/kluster-vendor-crun
#
# 输出：
#   $GITHUB_OUTPUT 里的 missing=<逗号分隔版本> 全部已发布时为空串

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

TRACKED_RELEASES="${TRACKED_RELEASES:-5}"
UPSTREAM_REPO="${UPSTREAM_REPO:-containers/crun}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

# GitHub 的 releases 接口按发布时间倒序返回
gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${UPSTREAM_REPO}/releases?per_page=100" \
    --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name' \
    > "${workdir}/upstream.txt"

# 只要 X.Y.Z，rc / alpha / beta 这类即使没打 prerelease 标记也挡在外面。
# 同时补上 v 前缀，对齐本仓库的 Release tag
grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' "${workdir}/upstream.txt" \
    | sed 's/^/v/' > "${workdir}/stable.txt" || true
if [[ ! -s "${workdir}/stable.txt" ]]; then
    fail "no stable upstream releases found, ${UPSTREAM_REPO} API response looks wrong"
fi

head -n "${TRACKED_RELEASES}" "${workdir}/stable.txt" > "${workdir}/tracked.txt"

echo "tracked upstream releases (latest ${TRACKED_RELEASES}):"
cat "${workdir}/tracked.txt"

gh release list --limit 500 --json tagName --jq '.[].tagName' \
    > "${workdir}/released.txt"

# 用 grep 而不是 comm，保住上游的时间倒序，新版本排在构建矩阵前面
missing="$(grep -F -x -v -f "${workdir}/released.txt" "${workdir}/tracked.txt" || true)"
missing="$(printf '%s' "${missing}" | paste -sd, -)"

echo "missing=${missing}"
emit_output "missing=${missing}"

{
    echo "### Upstream scan"
    echo
    echo "- tracked (latest ${TRACKED_RELEASES} releases): \`$(paste -sd, - < "${workdir}/tracked.txt")\`"
    if [[ -n "${missing}" ]]; then
        echo "- missing: \`${missing}\`"
    else
        echo "- missing: _none, everything is up to date_"
    fi
} | emit_summary

if [[ -z "${missing}" ]]; then
    echo "up to date, nothing to build"
fi
