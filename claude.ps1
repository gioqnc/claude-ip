if ($MyInvocation.PipelineLength -gt 1) {
    $input | & "$PSScriptRoot\claude-safe.ps1" @args
} else {
    & "$PSScriptRoot\claude-safe.ps1" @args
}
exit $LASTEXITCODE
