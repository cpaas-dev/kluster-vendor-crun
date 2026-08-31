## 打包

```bash
# 构建多架构镜像 amd64/arm64
docker buildx build --platform linux/amd64,linux/arm64 \
  -t xxx .
```

## 指定版本

```bash
# 带 v 前缀，构建时会剥掉再拼上游下载地址
docker buildx build \
  --build-arg INST_CRUN_V=v1.29.1 \
  -t ...
```

crun 的版本号有 `vX.Y`（如 `v1.28`，相当于别家的 `.0`）和 `vX.Y.Z`（如 `v1.29.1`）
两种形态，都能直接填。注意不要给两段的版本补零——上游的发布件叫
`crun-1.28-linux-amd64`，写成 `v1.28.0` 拼出来的地址会 404。

## 下载加速

```bash
# 国内访问加速
docker buildx build \
  --build-arg GITHUB_URL=https://gh-proxy.org/https://github.com \
  -t ...

# 本地自建 Nexus 代理
docker buildx build \
  --build-arg GITHUB_URL=https://nexus-mirror.alpha-quant.tech/repository/github \
  -t ...
```

## GPG 校验（可选）

crun 上游不发 `.sha256sum`，只发 GPG detached 签名。默认不校验，只做 ELF 检查。
想在构建期验签，填入签名者指纹即可：

```bash
docker buildx build \
  --build-arg CRUN_GPG_KEYS="<签名者指纹>" \
  -t ...
```

多个指纹用空格分隔。开启后构建会 `dnf install gnupg2` 并从 keyserver 拉公钥，
验签不过直接失败。keyserver 可以换：

```bash
--build-arg GPG_KEYSERVER=hkps://keyserver.ubuntu.com
```

指纹自己从上游确认，本仓库不硬编码——写死一个没核对过的指纹，比不校验更糟。

## 其他 build-args

```bash
# 基础镜像
BASE_IMAGE=docker.io/rockylinux/rockylinux:10.2.20260525.0

# 下载哪些架构的二进制，空格分隔。
# 最终镜像只装 TARGETARCH，这里改小只能省下载量，改小于目标架构集合会构建失败。
# 上游还发 ppc64le / riscv64 / s390x，ELF 检查也认这几个
VENDOR_ARCHES="amd64 arm64"
```

上游每个架构还发一个 `-disable-systemd` 变体，本仓库固定取默认的那个
（链接 systemd，Kubernetes 的 systemd cgroup driver 需要它），没有开关。
