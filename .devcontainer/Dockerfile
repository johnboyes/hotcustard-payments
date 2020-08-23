ARG VARIANT=2
FROM mcr.microsoft.com/vscode/devcontainers/ruby:${VARIANT}

#     Make sure gpg is available to git, for signing commits
RUN git config --global gpg.program "$(which gpg)" && \
    # Set Visual Studio Code as the git editor
    git config --global core.editor "code --wait"

# Install additional OS packages.
ARG HADOLINT_VERSION="v1.18.0"
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends redis-server=5:5.0.3-4+deb10u2 \
# Install hadolint
    && mkdir -p /tmp/hadolint \
    && wget -q -O tmp/hadolint/hadolint "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
    && install -m 755 /tmp/hadolint/hadolint /usr/local/bin/hadolint \
# Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/hadolint

# Install additional gems.
RUN gem install rubocop:0.89.1 reek:6.0.1

# (See https://github.com/hadolint/hadolint/wiki/DL4006 for more info on the pipefail setting)
SHELL ["/bin/bash", "-o", "pipefail", "-c"] 
# Install heroku (https://devcenter.heroku.com/articles/heroku-cli#standalone-installation)
RUN wget -q https://cli-assets.heroku.com/install.sh | sh
