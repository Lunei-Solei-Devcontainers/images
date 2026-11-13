ARG VARIANT=10.0-resolute
ARG REMOTE_USER=devcontainer
FROM mcr.microsoft.com/dotnet/sdk:${VARIANT}

# Redeclare
ARG VARIANT
ARG REMOTE_USER

ENV PATH $PATH:/home/${REMOTE_USER}/.dotnet:/home/${REMOTE_USER}/.dotnet/tools
RUN chmod -R a+w /usr/share/dotnet

# Remove ubuntu user
RUN if [ "${VARIANT#*noble}" != "$VARIANT" ] || [ "${VARIANT#*resolute}" != "$VARIANT" ]; then \
        if id "ubuntu" &>/dev/null; then \
            echo "Deleting user 'ubuntu' for $VARIANT" && userdel -f -r ubuntu || echo "Failed to delete ubuntu user for $VARIANT"; \
        else \
            echo "User 'ubuntu' does not exist for $VARIANT"; \
        fi; \
    fi

# Install dependencies for GPG key signing
RUN apt-get update \
    && apt-get install -y --no-install-recommends gnupg2 \
    && rm -rf /var/lib/apt/lists/*

RUN install -d -m 700 -o ${REMOTE_USER} -g ${REMOTE_USER} /home/${REMOTE_USER}/.gnupg

# Unset this so NuGet can extract XML documentation from packages for IntelliSense
ENV NUGET_XML_DOC_MODE=

LABEL devcontainer.metadata="[{ \
    \"remoteUser\": \"${REMOTE_USER}\", \
    \"updateRemoteUserUID\": true, \
    \"customizations\": { \
        \"jetbrains\": { \
            \"settings\": { \
                \"com.intellij:app:Vcs-Log-App-Settings.show_changes_from_parents\": true, \
                \"com.intellij:app:HttpConfigurable.use_proxy_pac\": true, \
                \"JavaScript:app:JSEditorOptions.automatically_replace_with_template_string_on_typing\": false, \
                \"JavaScript:app:JSEditorOptions.escape_pasted_text\": false, \
                \"JavaScript:app:JSEditorOptions.close_html_single_tags\": false, \
                \"JavaScript:app:JSEditorOptions.escape_doc_on_copy_paste\": false \
            } \
        } \
    }, \
    \"features\": { \
        \"ghcr.io/devcontainers/features/dotnet:2\": \"latest\", \
        \"ghcr.io/devcontainers/features/git:1\": {}, \
        \"ghcr.io/devcontainers/features/common-utils:1\": { \
            \"installZsh\": false, \
            \"installOhMyZsh\": false, \
            \"installOhMyZshConfig\": false, \
            \"username\": \"${REMOTE_USER}\", \
            \"upgradePackages\": true \
        } \
    } \
}]"
