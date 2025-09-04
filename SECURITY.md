# Security Policy

## Supported Versions

This project supports the following PowerShell versions:

| Version | Supported          |
| ------- | ------------------ |
| 7.x     | ✅ Yes             |
| 5.1     | ✅ Yes             |
| < 5.1   | ❌ No              |

## Reporting a Vulnerability

If you discover a security vulnerability in any of these scripts, please follow these steps:

1. **Do not** create a public GitHub issue
2. Send an email to the repository maintainer with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fixes (if any)

3. Allow time for assessment and resolution
4. Security issues will be prioritized and addressed promptly

## Security Considerations

### Script Execution
- Always review scripts before execution
- Run scripts in test environments first
- Ensure you have appropriate permissions
- Use execution policies appropriately

### Credentials and Sensitive Data
- Never hardcode credentials in scripts
- Use secure credential storage methods
- Be cautious with scripts that handle sensitive data
- Remove sensitive information from logs

### Registry and System Modifications
- Scripts that modify registry require special attention
- Always backup systems before running modification scripts
- Test registry changes in isolated environments
- Understand the impact of system modifications

### Network Operations
- Be cautious with scripts that connect to remote systems
- Validate network security requirements
- Use secure authentication methods
- Consider firewall and network policy implications

## Best Practices

1. **Principle of Least Privilege**: Run scripts with minimum required permissions
2. **Input Validation**: Validate all user inputs and parameters
3. **Error Handling**: Implement comprehensive error handling
4. **Logging**: Log security-relevant events appropriately
5. **Code Review**: Have scripts reviewed by other team members
6. **Testing**: Test scripts thoroughly in safe environments

## Disclaimer

These scripts are provided "as-is" without warranty. Users are responsible for:
- Testing scripts in their environment
- Understanding script functionality before execution
- Ensuring compliance with organizational security policies
- Backing up systems before making changes

Use these scripts at your own risk and always follow your organization's security guidelines.
