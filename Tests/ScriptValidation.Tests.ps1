#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for validating PowerShell scripts in the repository.

.DESCRIPTION
    Validates script syntax, parameter declarations, help documentation,
    and coding standards across all scripts in the Scripts directory.
#>

BeforeDiscovery {
    $ScriptFiles = Get-ChildItem -Path "$PSScriptRoot\..\Scripts" -Recurse -Filter "*.ps1"
}

Describe "Script Validation: <_.Name>" -ForEach $ScriptFiles {
    BeforeAll {
        $ScriptPath = $_.FullName
        $ScriptContent = Get-Content $ScriptPath -Raw
        $ScriptHelp = Get-Help $ScriptPath -ErrorAction SilentlyContinue
    }

    Context "Syntax" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            [System.Management.Automation.PSParser]::Tokenize($ScriptContent, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }

    Context "Help Documentation" {
        It "Should have a SYNOPSIS" {
            $ScriptContent | Should -Match '\.SYNOPSIS'
        }

        It "Should have a DESCRIPTION" {
            $ScriptContent | Should -Match '\.DESCRIPTION'
        }

        It "Should have at least one EXAMPLE" {
            $ScriptContent | Should -Match '\.EXAMPLE'
        }

        It "Should have NOTES" {
            $ScriptContent | Should -Match '\.NOTES'
        }

        It "Should have a LINK" {
            $ScriptContent | Should -Match '\.LINK'
        }

        It "Should have a Version in NOTES" {
            $ScriptContent | Should -Match 'Version\s*:'
        }
    }

    Context "Coding Standards" {
        It "Should use CmdletBinding" {
            $ScriptContent | Should -Match '\[CmdletBinding'
        }

        It "Should not have trailing whitespace on lines" {
            $lines = $ScriptContent -split "`n"
            $trailingWhitespace = $lines | Where-Object { $_ -match '\S\s+$' }
            $trailingWhitespace.Count | Should -Be 0
        }

        It "Should use UTF-8 encoding for CSV exports" {
            if ($ScriptContent -match 'Export-Csv') {
                $ScriptContent | Should -Match 'Encoding\s+(UTF8|utf8)'
            }
        }
    }

    Context "Parameter Validation" {
        It "Should declare parameters documented in help" {
            if ($ScriptHelp.parameters.parameter) {
                foreach ($param in $ScriptHelp.parameters.parameter) {
                    $paramName = $param.Name
                    # Skip common parameters provided by CmdletBinding
                    if ($paramName -in @('WhatIf', 'Confirm', 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
                        continue
                    }
                    $ScriptContent | Should -Match "\`$$paramName" -Because "Parameter '$paramName' is documented but should be declared"
                }
            }
        }
    }
}
