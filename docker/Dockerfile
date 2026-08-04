# Imagem base para testar o PowerTerminal sem mexer na máquina real.
# Build:  docker build -t powerterminal-test -f docker/Dockerfile .
# Run:    docker run -it --rm powerterminal-test
# Dentro: ~/PowerTerminal/bin/powerterminal install --profile full --yes

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Apenas o estritamente necessário para rodar o powerterminal install.
# (Os pacotes extras virão do próprio script — esse é o ponto de testar.)
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo curl ca-certificates locales whiptail git \
      tzdata \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Cria usuário 'dev' com sudo passwordless (igual aos seus VMs)
RUN useradd -ms /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER dev
WORKDIR /home/dev

# Copia o repo do PowerTerminal dentro da imagem (em vez de mount, fica autocontido)
COPY --chown=dev:dev . /home/dev/PowerTerminal

ENV PATH="/home/dev/.local/bin:/home/dev/PowerTerminal/bin:${PATH}"

CMD ["/bin/bash", "-l"]
