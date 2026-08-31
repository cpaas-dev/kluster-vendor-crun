# kluster-vendor-crun

把上游 crun 的二进制重新打包成一个多架构 OCI 镜像，用于离线 / 内网环境分发。

[![Release](https://github.com/cpaas-dev/kluster-vendor-crun/actions/workflows/release.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-crun/actions/workflows/release.yml)
[![Scan upstream](https://github.com/cpaas-dev/kluster-vendor-crun/actions/workflows/scan-upstream.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-crun/actions/workflows/scan-upstream.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-informational)

```bash
docker pull ghcr.io/cpaas-dev/kluster-vendor-crun:v1.29.1
```

## 这是什么

离线部署容器运行时，需要 GitHub Release 上的 crun 发布件。和 containerd 不同，
crun 上游发的不是压缩包，就是一个静态链接的二进制，本仓库把它按目标架构放进镜像，
只装二进制，不带镜像、不带配置。

## 镜像内容

```plain
/cpaas/vendor/crun/
├── crun                                   # 目标架构
├── crun.sha256sum
└── crun-<ver>-linux-<arch>.asc            # 上游 GPG 签名，留作凭证
```

下游校验：

```bash
cd /cpaas/vendor/crun

sha256sum -c crun.sha256sum
```

说明：

- 上游 tag 不带 `v` 前缀，本仓库的镜像 tag 和 Release 统一带 `v`，其余和上游 1:1：
  `1.29.1` → `v1.29.1`，`1.28` → `v1.28`
- 二进制取自上游 `crun-<ver>-linux-<arch>`，原样落盘后改名成 `crun`
- 上游不提供 `.sha256sum`，只有 GPG detached 签名。所以 `crun.sha256sum` 是本仓库
  下载后自己算的，只能保证「镜像里的这个文件没被改过」，不等同于上游校验和
- 上游的 `.asc` 一并打进镜像，留作凭证，可以离线自行验签
- 构建期可选开启 GPG 校验，见 [自定义构建](docs/BUILD_YOUR_OWN.md)，默认关闭
- 没有校验和兜底，构建期会检查落盘文件确实是对应架构的 ELF（magic + `e_machine`），
  挡住镜像站返回 200 错误页这类情况
- 默认取链接 systemd 的那个二进制，不是 `-disable-systemd` 版；
  Kubernetes 的 systemd cgroup driver 需要它
- 只含目标架构。`linux/arm64` 的镜像里只有 arm64 的 crun

## 文档

- [自定义构建](docs/BUILD_YOUR_OWN.md) —— build-args、下载加速、GPG 校验
- [发布流程](docs/RELEASE.md) —— tag 规则、定时扫描、本地调试脚本
- [贡献指南](docs/CONTRIBUTING.md)

## 相关仓库

- crun <https://github.com/containers/crun>

## 许可

本仓库的构建脚本以 Apache-2.0 发布。打包进镜像的上游产物遵循其原始许可：
crun（GPL-2.0-only）。
