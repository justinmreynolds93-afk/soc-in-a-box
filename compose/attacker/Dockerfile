# Lightweight attacker box on the lab network. Tools for recon, brute force,
# and simulated C2 against the lab victims ONLY (see docs/scope.md).
FROM alpine:3.20

RUN apk add --no-cache \
        bash curl wget nmap nmap-scripts hydra openssh-client \
        bind-tools ncat tcpdump python3 py3-pip iproute2 jq

WORKDIR /root
COPY tools/ /root/tools/
CMD ["sleep", "infinity"]
