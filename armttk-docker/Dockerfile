FROM mcr.microsoft.com/powershell:latest

# Labels for GitHub Actions
LABEL "com.github.actions.name"="ARM Template Toolkit"
LABEL "com.github.actions.description"="Test ARM template using the ARM Template Toolkit"

RUN apt-get update && \
#	apt-get upgrade -y && \
	apt-get install -y git

# Clone ARM-TTK Repo
RUN git clone https://github.com/Azure/arm-ttk.git /src/arm-ttk
RUN git clone https://github.com/Yvand/AzureRM-Templates.git /src/AzureRM-Templates

# Copy the Entrypoint file from the current directory (the one the Dockerfile is located in)
COPY runarmttk.ps1 /src/runarmttk.ps1

# Start using the Entrypoint file.
ENTRYPOINT [ "pwsh", "/src/runarmttk.ps1" ]