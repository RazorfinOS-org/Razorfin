FROM scratch AS ctx
COPY build_files /build

FROM ghcr.io/ublue-os/brew:latest AS brew
FROM ghcr.io/projectbluefin/common:latest AS common

ARG BUILD_FLAVOR="${BUILD_FLAVOR:-}"

FROM ghcr.io/ublue-os/base-main:latest

ARG BUILD_FLAVOR

COPY --from=brew /system_files /
COPY --from=common /system_files/shared /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    BUILD_FLAVOR="${BUILD_FLAVOR}" bash /ctx/build/00-base.sh && \
    BUILD_FLAVOR="${BUILD_FLAVOR}" bash /ctx/build/01-cosmic.sh && \
    BUILD_FLAVOR="${BUILD_FLAVOR}" bash /ctx/build/02-nvidia.sh && \
    BUILD_FLAVOR="${BUILD_FLAVOR}" bash /ctx/build/99-cleanup.sh

RUN bootc container lint
