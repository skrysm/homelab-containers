#
# To build this directly, use:
#
#    docker build -t ansible-devcontainer:local .
#

# Ansible is written in Python - so we need a Python container.
FROM python:3.14-slim@sha256:cea0e6040540fb2b965b6e7fb5ffa00871e632eef63719f0ea54bca189ce14a6

# Use a UTF-8 locale that is available in Debian slim without installing the locales package.
# Fixes Ansible locale errors.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install Ansible:
#
# * ansible - Ansible itself including ansible-playbook and ansible-vault
# * ansible-lint - contains ansible-lint (required for linting playbooks and used by the VSCode Ansible extension)
# * passlib - required for the password_hash() function for the ansible.builtin.user
#
# NOTES:
# * Installing Ansible via pipx caused a lot of problems (primarily missing paths/modules
#   when running ansible-lint). So instead we install Ansible via pip (which worked out-of-the-box
#   without problems)
# * "pip3" simply means "pip for Python 3" (like "pip2" is for Python 2). By using "pip3" instead
#   of just "pip", we explicitly state that we want Python 3.
# * To see the installed version, use: pip3 show <package>
# * Release notes of pip packages: https://pypi.org/project/ansible/#history
# * Pin version with "ansible==11.0.*"
RUN pip3 install --no-cache-dir \
    ansible \
    ansible-lint \
    passlib

# Install additional software
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    # ping command
    iputils-ping \
    # required for VS Code/devcontainer basics
    git \
    sudo \
    zsh \
    nano \
    # required for Ansible to connect to hosts via SSH
    openssh-client \
    # required for Ansible to ask for SSH passwords (i.e. when using "-k")
    sshpass \
    # required for some dependency of ansible
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*

# Add non-root "vscode" user required for devcontainers.
RUN useradd --create-home --shell /bin/zsh vscode \
    && echo "vscode ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# Suppress warning about auto-selected python interpreter.
# Not sure what's supposed to be the solution for this warning (other than suppressing it).
# See: https://docs.ansible.com/ansible-core/2.18/reference_appendices/interpreter_discovery.html
ENV ANSIBLE_PYTHON_INTERPRETER=auto_silent

# Run the following commands as the "vscode" user.
USER vscode

# Install oh-my-zsh.
RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /home/vscode/.oh-my-zsh \
    && cp /home/vscode/.oh-my-zsh/templates/zshrc.zsh-template /home/vscode/.zshrc

# Create .ssh directory for (potential) custom ssh config
RUN mkdir -p /home/vscode/.ssh

# Switch from vim to nano as default editor (for example for ansible-vault).
# This has also the nice side effect that nano has syntax highlighting enabled
# by default whereas vim has not.
# NOTE: For DevContainers I'd recommend nano over micro because micro's keyboard shortcuts
#   often don't work because VSCode intercepts them and uses them for itself. Nano uses
#   different (i.e. more unconventional) shortcuts that do not interfere with VSCode.
ENV EDITOR=nano

# Just for convenience when running this container directly via "docker run -ti".
CMD ["/bin/zsh"]
