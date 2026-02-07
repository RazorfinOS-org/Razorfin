ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite:stable"

FROM scratch AS ctx
COPY build_files /build

FROM ${BASE_IMAGE}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build/00-remove-kde.sh && \
    bash /ctx/build/01-base.sh && \
    bash /ctx/build/02-cosmic.sh && \
    bash /ctx/build/03-cleanup-kde-frameworks.sh && \
    bash /ctx/build/99-cleanup.sh

RUN bootc container lint
