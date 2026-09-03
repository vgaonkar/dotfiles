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
        # also removed, but as a PRECAUTION, not because it was proven broken: its
        # behaviour under Windows PowerShell 5.1 was never established, and a bootstrap
        # installer that runs on fresh machines should not depend on an untested
        # construct. (A cascade of 5.1 syntax errors was briefly blamed on it; the
        # error text showed the file being parsed was a saved GitHub HTML page.)
        # Each script routes output through a single Write-Status helper regardless.
        'PSAvoidUsingWriteHost'
    )
}
