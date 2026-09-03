# Linux victim: a normal-looking Ubuntu host with SSH, running a Fleet-managed
# Elastic Agent. Built on the official agent image (Ubuntu 24.04) so enrollment
# is handled by `elastic-agent container`. Adversary emulation (M3) targets this
# container only — see docs/scope.md.
ARG STACK_VERSION=8.19.20
FROM docker.elastic.co/elastic-agent/elastic-agent:${STACK_VERSION}

USER root
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server sudo cron vim less iproute2 iputils-ping net-tools procps python3 curl \
        rsyslog \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd \
 && useradd -m -s /bin/bash analyst    && echo 'analyst:Password123!' | chpasswd && usermod -aG sudo analyst \
 && useradd -m -s /bin/bash svc-backup && echo 'svc-backup:Backup2024'  | chpasswd \
 && echo 'root:Toor123!' | chpasswd \
 && sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/; s/#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
        /etc/ssh/sshd_config \
 && sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

COPY victim-entrypoint.sh /usr/local/bin/victim-entrypoint
RUN chmod +x /usr/local/bin/victim-entrypoint

EXPOSE 22
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/victim-entrypoint"]
