## 发布流程

发布 = 一个多架构镜像 + 一个 GitHub Release，由 GitHub Actions 完成。

- 镜像：`ghcr.io/cpaas-dev/kluster-vendor-crun:<版本>`
- Release：tag 为上游版本号补上 `v` 前缀，notes 里只有一个上游 Release 链接

## Tag 规则

crun 上游 tag 不带 `v`，本仓库统一带 `v`，其余部分和上游 1:1，不做补零。

上游的版本号有两种形态，都要支持：

| 上游 | 本仓库 | 说明 |
| --- | --- | --- |
| `1.28` | `v1.28` | 相当于 `.0`，只有两段 |
| `1.29.1` | `v1.29.1` | patch 版本，三段 |

`vX.Y` / `vX.Y.Z` 都是一个 manifest list，同时含 `linux/amd64` 与 `linux/arm64`。

```bash
docker pull ghcr.io/cpaas-dev/kluster-vendor-crun:v1.29.1
docker buildx imagetools inspect ghcr.io/cpaas-dev/kluster-vendor-crun:v1.29.1
```

## 定时扫描（自动）

`.github/workflows/scan-upstream.yml` 每天 3 次（北京时间 10:37 / 18:37 / 02:37）
扫描 <https://github.com/containers/crun> 的 Release：

- 取上游最近 5 个正式 release（由 `TRACKED_RELEASES` 控制），按发布时间倒序，不按 minor 分组
- 排除 `draft` / `prerelease`，并要求 tag 严格匹配 `X.Y` 或 `X.Y.Z`，
  所以 `rc` / `alpha` / `beta`、以及 `0.12.2.1` 这种四段的老 tag 不会被构建
- 匹配后补上 `v` 前缀，再和本仓库已有的 Release 比对
- 这 5 个里本仓库还没发过的，才进构建矩阵

## 手动补发

`.github/workflows/release.yml` 可以 `workflow_dispatch`，`versions` 填逗号分隔的版本
列表（带 `v`，如 `v1.29.1,v1.28`）。已经有 Release 的版本会被跳过，不会覆盖。

## 调试

本地调试例子：

```bash
# 扫描未发布版本
GH_REPO=cpaas-dev/kluster-vendor-crun \
  .github/scripts/scan_upstream.bash

# 解析版本矩阵
GH_REPO=cpaas-dev/kluster-vendor-crun \
  VERSIONS=v1.29.1,v1.28 .github/scripts/resolve_versions.bash
```
