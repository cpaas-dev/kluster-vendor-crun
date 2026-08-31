# syntax=docker.io/docker/dockerfile:1.25.0

ARG BASE_IMAGE=docker.io/rockylinux/rockylinux:10.2.20260525.0

FROM --platform=${BUILDPLATFORM} ${BASE_IMAGE} AS base

ARG GITHUB_URL=https://github.com
# ARG GITHUB_URL=https://gh-proxy.org/https://github.com
# ARG GITHUB_URL=https://nexus-mirror.alpha-quant.tech/repository/github

# crun
# https://github.com/containers/crun/releases
ARG INST_CRUN_V=v1.29.1

ARG VENDOR_ARCHES="amd64 arm64"

ARG CRUN_GPG_KEYS=""
ARG GPG_KEYSERVER=hkps://keys.openpgp.org

ENV \
    GITHUB_URL=${GITHUB_URL} \
    INST_CRUN_V=${INST_CRUN_V} \
    VENDOR_ARCHES=${VENDOR_ARCHES} \
    CRUN_GPG_KEYS=${CRUN_GPG_KEYS} \
    GPG_KEYSERVER=${GPG_KEYSERVER}

# ---------------------------------------------------------------------------
# binaries
#    /cpaas/vendor/crun/<arch>/crun
#    /cpaas/vendor/crun/<arch>/crun.sha256sum
#    /cpaas/vendor/crun/<arch>/crun-<ver>-linux-<arch>[flavor].asc
#
# ---------------------------------------------------------------------------
FROM --platform=${BUILDPLATFORM} base AS binaries

ARG GNUPG_DIR=/root/.gnupg-build

RUN --mount=type=cache,target=/tmp,id=build-tmp,sharing=locked \
    set -eu \
    && ver="${INST_CRUN_V#v}" \
    && mkdir -p "${GNUPG_DIR}" \
    && if [ -n "${CRUN_GPG_KEYS}" ]; then \
    dnf install -y --setopt=install_weak_deps=False gnupg2 >/dev/null ; \
    export GNUPGHOME="${GNUPG_DIR}/home" ; \
    mkdir -p -m 700 "${GNUPGHOME}" ; \
    for key in ${CRUN_GPG_KEYS}; do \
    gpg --batch --keyserver "${GPG_KEYSERVER}" --recv-keys "${key}" ; \
    done ; \
    gpg --batch --export > "${GNUPG_DIR}/keyring.gpg" ; \
    test -s "${GNUPG_DIR}/keyring.gpg" \
    || { echo "empty keyring, no key imported" >&2; exit 1; } ; \
    fi \
    && for arch in ${VENDOR_ARCHES}; do \
    bin="crun-${ver}-linux-${arch}" ; \
    dst="/cpaas/vendor/crun/${arch}" ; \
    base_url="${GITHUB_URL}/containers/crun/releases/download/${ver}" ; \
    curl --fail -sL -m 300 --retry 3 --retry-delay 5 \
    "${base_url}/${bin}" -o "/tmp/${bin}" ; \
    curl --fail -sL -m 60 --retry 3 --retry-delay 5 \
    "${base_url}/${bin}.asc" -o "/tmp/${bin}.asc" ; \
    if [ -s "${GNUPG_DIR}/keyring.gpg" ]; then \
    gpgv --keyring "${GNUPG_DIR}/keyring.gpg" "/tmp/${bin}.asc" "/tmp/${bin}" ; \
    fi ; \
    mkdir -p "${dst}" ; \
    cp "/tmp/${bin}" "${dst}/crun" ; \
    chmod +x "${dst}/crun" ; \
    cp "/tmp/${bin}.asc" "${dst}/${bin}.asc" ; \
    ( cd "${dst}" && sha256sum crun > crun.sha256sum ) ; \
    done

RUN set -eu \
    && for arch in ${VENDOR_ARCHES}; do \
    dst="/cpaas/vendor/crun/${arch}" ; \
    test -x "${dst}/crun" \
    || { echo "missing binary: ${arch}/crun" >&2; exit 1; } ; \
    test -s "${dst}/crun.sha256sum" \
    || { echo "missing checksum: ${arch}/crun.sha256sum" >&2; exit 1; } ; \
    magic="$(od -An -tx1 -N4 "${dst}/crun" | tr -d ' \n')" ; \
    test "${magic}" = "7f454c46" \
    || { echo "not an ELF binary: ${arch}/crun (magic=${magic})" >&2; exit 1; } ; \
    case "${arch}" in \
    amd64) want="3e00" ;; \
    arm64) want="b700" ;; \
    ppc64le) want="1500" ;; \
    riscv64) want="f300" ;; \
    s390x) want="0016" ;; \
    *) want="" ;; \
    esac ; \
    machine="$(od -An -tx1 -j18 -N2 "${dst}/crun" | tr -d ' \n')" ; \
    { test -z "${want}" || test "${machine}" = "${want}" ; } \
    || { echo "ELF arch mismatch: ${arch}/crun (e_machine=${machine}, want=${want})" >&2; exit 1; } ; \
    ( cd "${dst}" && sha256sum --check --strict ./*.sha256sum ) ; \
    done

# ---------------------------------------------------------------------------
# target
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG TARGETARCH

# crun
# https://github.com/containers/crun/releases
ARG INST_CRUN_V=v1.29.1

ENV INST_CRUN_V=${INST_CRUN_V}

COPY --from=binaries /cpaas/vendor/crun/${TARGETARCH}/ /cpaas/vendor/crun/

LABEL \
    org.opencontainers.image.title="kluster-vendor-crun" \
    org.opencontainers.image.description="Upstream crun binaries repackaged as OCI artifacts" \
    org.opencontainers.image.version="${INST_CRUN_V}" \
    org.opencontainers.image.source="https://github.com/cpaas-dev/kluster-vendor-crun" \
    org.opencontainers.image.vendor="Kluster" \
    org.opencontainers.image.licenses="Apache-2.0"
