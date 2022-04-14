FROM mcr.microsoft.com/powershell:latest

# Labels for GitHub Actions
LABEL "com.github.actions.name"="ARM Template Toolkit"
LABEL "com.github.actions.description"="Test ARM template using the ARM Template Toolkit"

RUN apt-get update && \
#	apt-get upgrade -y && \
	apt-get install -y git

# Clone ARM-TTK Repo
ENV ARMTTK_PATH="/src/arm-ttk"
RUN git clone --depth 1 https://github.com/Azure/arm-ttk.git $ARMTTK_PATH

# Copy the Entrypoint file from the current directory (the one the Dockerfile is located in)
COPY entrypoint.ps1 /src/entrypoint.ps1

# Start using the Entrypoint file.
ENTRYPOINT [ "pwsh", "/src/entrypoint.ps1" ]