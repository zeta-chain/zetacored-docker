FROM golang:1.22.5-bookworm AS base-build

RUN go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0
RUN go install github.com/hashicorp/go-getter/cmd/go-getter@v1.7.6

FROM debian:bookworm AS base

RUN mkdir -p /root/.zetacored/cosmovisor/genesis/bin && \
    ln -s /root/.zetacored/cosmovisor/genesis /root/.zetacored/cosmovisor/current

ENV PATH=/root/.zetacored/cosmovisor/current/bin/:${PATH}

RUN apt update && \
    apt install -y ca-certificates curl jq && \
    rm -rf /var/lib/apt/lists/*

COPY --from=base-build /go/bin/cosmovisor /go/bin/go-getter /usr/local/bin

COPY run.sh init.sh /

VOLUME /root/.zetacored/data/

ENTRYPOINT ["/run.sh"]

FROM base AS snapshotter

ARG TARGETARCH

RUN apt update && \
    apt install -y rclone && \
    rm -rf /var/lib/apt/lists/*

RUN ARCH=$( [ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "$TARGETARCH" ) && \
    curl -L https://github.com/zeta-chain/cosmprund/releases/download/v0.2.0-zeta/cosmprund_Linux_${ARCH}.tar.gz | tar xz -C /usr/local/bin/ cosmprund &&\
    chmod +x /usr/local/bin/cosmprund