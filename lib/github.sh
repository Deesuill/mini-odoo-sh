#!/bin/bash

github_repository() {
    local repo_name="$1"

    echo "$GITHUB_OWNER/$repo_name"
}

github_repo_name() {
    local repository="$1"

    basename "$repository" .git
}

github_require_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI is not installed."
    fi
}

github_require_token() {
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log_error "GITHUB_TOKEN is not configured."
    fi

    export GH_TOKEN="$GITHUB_TOKEN"
}

github_prepare() {
    github_require_cli
    github_require_token
}

github_deploy_key_path() {
    local instance_name="$1"

    echo "$MINI_ODOO_HOME/keys/$instance_name/deploy_key"
}

github_deploy_public_key_path() {
    local instance_name="$1"

    echo "$MINI_ODOO_HOME/keys/$instance_name/deploy_key.pub"
}

github_generate_deploy_key() {
    local instance_name="$1"
    local key_directory
    local key_path

    key_directory="$MINI_ODOO_HOME/keys/$instance_name"
    key_path=$(github_deploy_key_path "$instance_name")

    log_info "Generating deploy key for instance: $instance_name"

    mkdir -p "$key_directory"

    rm -f -- "$key_path" "$key_path.pub"

    ssh-keygen \
        -t ed25519 \
        -N "" \
        -f "$key_path" \
        -C "mini-odoo-$instance_name"

    log_success "Deploy key generated: $key_path"
}

github_add_deploy_key() {
    local instance_name="$1"
    local repo_name="$2"
    local public_key_path
    local repository
    local title

    github_prepare

    public_key_path=$(github_deploy_public_key_path "$instance_name")
    repository=$(github_repository "$repo_name")
    title="mini-odoo-$instance_name"

    if [ ! -f "$public_key_path" ]; then
        log_error "Public deploy key not found: $public_key_path"
    fi

    log_info "Adding deploy key to GitHub repository: $repository"

    gh repo deploy-key add "$public_key_path" \
        --repo "$repository" \
        --title "$title" \
        --allow-write

    log_success "Deploy key added."
}

github_server_host() {
    hostname -I | awk '{print $1}'
}

github_add_actions_secrets() {
    local repo_name="$1"
    local repository
    local platform_key
    local server_host
    local server_user

    github_prepare

    repository=$(github_repository "$repo_name")
    platform_key="$MINI_ODOO_HOME/platform/platform_key"
    server_host=$(github_server_host)
    server_user="${MINI_ODOO_SERVER_USER:-miniodoo}"

    if [ ! -f "$platform_key" ]; then
        log_error "Platform SSH key not found: $platform_key"
    fi

    if [ -z "$server_host" ]; then
        log_error "Unable to determine server IP address."
    fi

    log_info "Adding GitHub Actions secrets to: $repository"

    gh secret set SERVER_HOST \
        --repo "$repository" \
        --body "$server_host"

    gh secret set SERVER_USER \
        --repo "$repository" \
        --body "$server_user"

    gh secret set SERVER_SSH_KEY \
        --repo "$repository" \
        < "$platform_key"

    log_success "GitHub Actions secrets added."
}

github_bootstrap_instance() {
    local instance_name="$1"
    local repository="$2"
    local repo_name

    repo_name=$(github_repo_name "$repository")

    github_generate_deploy_key "$instance_name"
    github_add_deploy_key "$instance_name" "$repo_name"
    github_add_actions_secrets "$repo_name"
}
