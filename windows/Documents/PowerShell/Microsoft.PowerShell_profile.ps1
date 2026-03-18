# PowerShell 7 profile — mirrors fish config for consistent cross-platform experience

# Aliases (match fish abbreviations)
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Set-Alias -Name ls -Value eza -Option AllScope -Force
    function ll { eza -al @args }
    function la { eza -a @args }
    function l { eza -F @args }
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name cat -Value bat -Option AllScope -Force
}

# Tool initializations
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border'
}

# Git delta as default pager
if (Get-Command delta -ErrorAction SilentlyContinue) {
    $env:GIT_PAGER = 'delta'
}

# PSReadLine enhancements (only in interactive terminals)
if ((Get-Module -ListAvailable PSReadLine) -and [System.Console]::IsOutputRedirected -eq $false) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}
