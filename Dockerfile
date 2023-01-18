ARG CUDA_IMAGE=nvidia/cuda:11.8.0-runtime-ubuntu20.04
FROM ${CUDA_IMAGE}

# from https://stackoverflow.com/questions/71852720/docker19-03-dind-could-not-select-device-driver-nvidia-with-capabilities

RUN apt-get update -q && \
    apt-get install -yq \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"  && \
    apt-get update -q && apt-get install -yq docker-ce docker-ce-cli containerd.io

# https://github.com/docker/docker/blob/master/project/PACKAGERS.md#runtime-dependencies
RUN set -eux; \
    apt-get update -q && \
    apt-get install -yq \
        btrfs-progs \
        e2fsprogs \
        iptables \
        xfsprogs \
        xz-utils \
# pigz: https://github.com/moby/moby/pull/35697 (faster gzip implementation)
        pigz \
#        zfs \
        wget


# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -x \
    && addgroup --system dockremap \
    && adduser --system -ingroup dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid

# https://github.com/docker/docker/tree/master/hack/dind
ENV DIND_COMMIT 37498f009d8bf25fbb6199e8ccd34bed84f2874b

RUN set -eux; \
    wget -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
    chmod +x /usr/local/bin/dind


##### Install nvidia docker #####
# Add the package repositories
RUN curl -fsSL https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add --no-tty -

RUN distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && \
    echo $distribution &&  \
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
      tee /etc/apt/sources.list.d/nvidia-docker.list

RUN apt-get update -qq --fix-missing

RUN apt-get install -yq nvidia-docker2

RUN sed -i '2i \ \ \ \ "default-runtime": "nvidia",' /etc/docker/daemon.json

RUN mkdir -p /usr/local/bin/

RUN wget https://raw.githubusercontent.com/docker-library/docker/0997ca7ad1d7892324d84951d55192d5ef629bcc/dockerd-entrypoint.sh -P /usr/local/bin/
#COPY dockerd-entrypoint.sh /usr/local/bin/
RUN chmod 777 /usr/local/bin/dockerd-entrypoint.sh
RUN ln -s /usr/local/bin/dockerd-entrypoint.sh /

VOLUME /var/lib/docker
EXPOSE 2375


RUN apt-get install -y uidmap iproute2 fuse-overlayfs docker-ce-rootless-extras
#RUN mkdir /run/user 
RUN chmod 1777 /run/user
RUN adduser rootless --home /home/rootless --gecos 'Rootless' --disabled-password --uid 1000 
RUN echo 'rootless:100000:65536' >> /etc/subuid
RUN echo 'rootless:100000:65536' >> /etc/subgid
RUN mkdir -p /home/rootless/.local/share/docker; 
RUN chown -R rootless:rootless /home/rootless/.local/share/docker
VOLUME /home/rootless/.local/share/docker
USER rootless
ENTRYPOINT ["dockerd-entrypoint.sh"]
#ENTRYPOINT ["/bin/sh", "/shared/dockerd-entrypoint.sh"]
CMD []