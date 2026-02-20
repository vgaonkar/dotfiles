@{
    IncludeRules = @(
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInternalURLs',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingWriteHost',
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
        'PSAvoidUsingInvokeExpression'
    )
}
