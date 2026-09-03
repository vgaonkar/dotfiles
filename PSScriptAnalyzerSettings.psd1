@{
    IncludeRules = @(
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInternalURLs',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingWMICmdlet',
        'PSMissingModuleManifestField',
        'PSPossibleIncorrectComparisonWithNull',
        'PSProvideDefaultParameterValue',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSUseApprovedVerbs',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseSingularNouns',
        'PSUseStandardConventionsForParameters'
    )
    ExcludeRules = @(
        'PSAvoidUsingInvokeExpression',
        # Deliberately off. These scripts are interactive operator tools whose console
        # output is the product, and Write-Host is the ONLY writer Start-Transcript
        # captures -- $Host.UI.WriteLine is not, which silently emptied every run log
        # when it was tried. The per-function SuppressMessageAttribute alternative was
        # also reverted: it failed to parse under Windows PowerShell 5.1, breaking the
        # fresh-machine bootstrap installers outright.
        # Each script routes output through a single Write-Status helper regardless.
        'PSAvoidUsingWriteHost'
    )
}
