# Windows Integration

This directory previously contained automatic Windows integration scripts that required PowerShell execution policy changes and administrative access. These have been removed in favor of simpler, manual setup approaches.

## Docker Integration

To use Docker from Windows PowerShell after installing Docker Engine in WSL:

```powershell
# From Windows PowerShell
wsl -d Ubuntu-26.04 docker ps
```

For a PowerShell function wrapper, add this to your PowerShell profile:

```powershell
# Add to $PROFILE
function docker {
    wsl -d Ubuntu-26.04 docker @Args
}

function docker-compose {
    wsl -d Ubuntu-26.04 docker-compose @Args
}
```

## Corporate CA Certificates

If your network uses TLS interception and you need to import corporate CA certificates into Windows:

```powershell
# Requires admin rights
certutil -addstore -f "ROOT" "path\to\corporate-ca.crt"
```

## Windows Terminal

For the best WSL experience, install Windows Terminal:

```powershell
winget install Microsoft.WindowsTerminal
```

## Benefits of Manual Setup

- No PowerShell execution policy changes required
- No administrative access needed for most operations
- Clear understanding of what's being configured
- Works with restricted corporate environments