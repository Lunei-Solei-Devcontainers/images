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

# Unset this so NuGet can extract XML documentation from packages for IntelliSense
ENV NUGET_XML_DOC_MODE=
