ARG VARIANT=2
FROM mcr.microsoft.com/vscode/devcontainers/ruby:${VARIANT}

# Install Sinatra
# hadolint ignore=DL3028
RUN gem install sinatra sinatra-reloader thin data_mapper dm-sqlite-adapter 

# Install a version of Node.js using nvm for dynamic front end content
ARG NODE_VERSION="lts/*"
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"

#     Make sure gpg is available to git, for signing commits
RUN git config --global gpg.program "$(which gpg)" && \
    # Set Visual Studio Code as the git editor
    git config --global core.editor "code --wait"

# Install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends redis-server=5:5.0.3-4+deb10u2 \
# Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install additional gems.
RUN gem install rubocop -v "=0.89.1"

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1
