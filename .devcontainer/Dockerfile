ARG VARIANT=2
FROM mcr.microsoft.com/vscode/devcontainers/ruby:${VARIANT}

    # Make sure gpg is available to git, for signing commits
RUN git config --global gpg.program "$(which gpg)" && \
    # Set Visual Studio Code as the git editor
    git config --global core.editor "code --wait"


# Install hadolint
ARG HADOLINT_VERSION="v1.18.0"
# (See https://github.com/hadolint/hadolint/wiki/DL4006 for more info on the pipefail setting) 
# Install heroku (https://devcenter.heroku.com/articles/heroku-cli#standalone-installation)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /tmp/hadolint \
    && wget -q -O tmp/hadolint/hadolint "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
    && install -m 755 /tmp/hadolint/hadolint /usr/local/bin/hadolint \
    && rm -rf /tmp/hadolint \
    # Install Heroku
    && wget -qO- "https://cli-assets.heroku.com/heroku-linux-x64.tar.gz" | tar xz -C /usr/local/lib \
    && ln -s /usr/local/lib/heroku/bin/heroku /usr/local/bin/heroku \
    && heroku --version

# Install additional gems.
RUN gem install rubocop:0.91.1 reek:6.0.1
