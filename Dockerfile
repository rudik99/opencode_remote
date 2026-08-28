FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/home/opencode/.opencode/bin:/usr/local/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl fd-find git git-lfs gh gnupg \
      jq less nano openssh-client procps python3 python3-pip ripgrep unzip \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

# Current Docker CLI with Buildx and Compose; the daemon runs in DinD.
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && . /etc/os-release \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      docker-buildx-plugin docker-ce-cli docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

# Node 22 is used by local MCP servers and JavaScript projects.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Official Claude Code CLI for subscription-backed delegated tasks.
ARG CLAUDE_CODE_VERSION=2.1.250
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && claude --version

RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xdg-open \
 && chmod +x /usr/local/bin/xdg-open

ARG OPENCODE_UID=1000
ARG OPENCODE_GID=1000
RUN if getent group "${OPENCODE_GID}" >/dev/null; then \
      group_name=$(getent group "${OPENCODE_GID}" | cut -d: -f1); \
    else \
      group_name=opencode; \
      groupadd -g "${OPENCODE_GID}" "${group_name}"; \
    fi \
 && useradd -m -u "${OPENCODE_UID}" -g "${group_name}" -s /bin/bash opencode \
 && mkdir -p /workspace \
 && chown "${OPENCODE_UID}:${OPENCODE_GID}" /workspace

USER opencode
WORKDIR /home/opencode

ARG OPENCODE_VERSION=latest
RUN mkdir -p \
      /home/opencode/.ssh \
      /home/opencode/.config/opencode \
      /home/opencode/.local/share/opencode \
      /home/opencode/.opencode \
 && ssh-keyscan github.com >> /home/opencode/.ssh/known_hosts 2>/dev/null || true

RUN if [ "${OPENCODE_VERSION}" = "latest" ]; then \
      curl -fsSL https://opencode.ai/install | bash; \
    else \
      curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}"; \
    fi

WORKDIR /workspace
ENTRYPOINT ["opencode"]
CMD ["web", "--hostname", "0.0.0.0", "--port", "4096"]
