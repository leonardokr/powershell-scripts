# Contributing to PowerShell Scripts Collection

Thank you for considering contributing to this PowerShell scripts collection! This document provides guidelines for contributions.

## How to Contribute

### Reporting Issues
- Use the GitHub issue tracker to report bugs or request features
- Provide clear descriptions and steps to reproduce issues
- Include PowerShell version and Windows version information

### Submitting Scripts
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-script`)
3. Add your script following the guidelines below
4. Commit your changes (`git commit -am 'Add new script: ScriptName'`)
5. Push to the branch (`git push origin feature/new-script`)
6. Create a Pull Request

## Script Guidelines

### Code Standards
- Use PowerShell 5.1+ compatible syntax
- Follow PowerShell best practices and naming conventions
- Include comprehensive comment-based help
- Use approved PowerShell verbs for function names
- Include error handling with try/catch blocks

### Documentation Requirements
- Complete comment-based help with:
  - `.SYNOPSIS`
  - `.DESCRIPTION`
  - `.PARAMETER` for each parameter
  - `.EXAMPLE` with realistic examples
  - `.NOTES` with prerequisites and warnings
  - `.LINK` to relevant documentation

### File Structure
```
Scripts/
├── Category/
│   ├── ScriptName.ps1
│   └── README.md
```

### Naming Convention
- Use approved PowerShell verbs (Get-, Set-, New-, Remove-, etc.)
- Use PascalCase for script names
- Be descriptive and specific

### Script Template
```powershell
<#
.SYNOPSIS
    Brief description of what the script does.

.DESCRIPTION
    Detailed description of the script's functionality.

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    .\ScriptName.ps1 -Parameter Value
    
    Description of what this example does.

.NOTES
    File Name      : ScriptName.ps1
    Author         : Your Name
    Prerequisite   : Required modules/permissions
    Creation Date  : YYYY-MM-DD

.LINK
    Relevant documentation URL
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ParameterName
)

# Script implementation
```

### Testing
- Test scripts in non-production environments
- Include error scenarios in testing
- Verify compatibility across PowerShell versions where possible

### Security Considerations
- Never hardcode credentials or sensitive information
- Use secure methods for handling passwords
- Include warnings for scripts that modify system settings
- Validate input parameters appropriately

## Categories

Organize scripts into appropriate categories:
- **ActiveDirectory** - AD user and object management
- **FileSystem** - File and folder operations
- **NetworkShares** - SMB shares and DFS management
- **TaskScheduler** - Scheduled task management
- **UserProfiles** - Windows user profile operations
- **SystemMaintenance** - General system maintenance
- **Monitoring** - System and service monitoring
- **Security** - Security-related operations

## Review Process

1. All submissions are reviewed for:
   - Code quality and best practices
   - Documentation completeness
   - Security considerations
   - Usefulness to the community

2. Reviewers may request changes or improvements

3. Once approved, scripts are merged into the main branch

## Questions?

Feel free to open an issue for any questions about contributing or create a discussion for general questions about the scripts.

Thank you for contributing!
