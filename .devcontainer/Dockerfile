
FROM maven:3.8.2-jdk-11

ARG NODE_VERSION=14.17.6


RUN apt update && apt install -y curl sudo

ARG USER_NAME=keycloak
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN useradd -ms /bin/bash $USER_NAME && echo "$USER_NAME:$USER_NAME" | chpasswd && adduser $USER_NAME sudo
RUN if [ "$USER_GID" != "1000" ] || [ "$USER_UID" != "1000" ]; then groupmod --gid $USER_GID $USER_NAME && usermod --uid $USER_UID --gid $USER_GID $USER_NAME; fi

USER $USER_NAME

RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.38.0/install.sh | bash
ENV NVM_DIR=/home/$USER_NAME/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="$NVM_DIR/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm --version
RUN npm i -g lix