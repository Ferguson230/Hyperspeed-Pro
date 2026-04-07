# Contributing to HyperSpeed Pro

Thank you for your interest in contributing to HyperSpeed Pro! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Submission Process](#submission-process)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inspiring community for all. Please be respectful and constructive in your interactions.

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes:**
- Harassment, trolling, or insulting comments
- Personal or political attacks
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:
- Ubuntu 22.04 or 24.04 LTS test environment
- cPanel/WHM installation (development license)
- Basic knowledge of:
  - PHP 8.0+
  - Perl 5.16+
  - Bash scripting
  - Redis/Memcached
  - Nginx configuration

### Fork the Repository

1. Fork the repository to your GitHub account
2. Clone your fork locally:
   ```bash
   git clone https://github.com/Ferguson230/Hyperspeed-Pro.git
   cd hyperspeed-pro
   ```

3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/Ferguson230/Hyperspeed-Pro.git
   ```

4. Create a branch for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## How to Contribute

### Reporting Bugs

**Before submitting a bug report:**
- Check existing issues to avoid duplicates
- Verify the bug exists in the latest version
- Collect relevant system information

**Bug report should include:**
- Clear, descriptive title
- Exact steps to reproduce the issue
- Expected vs. actual behavior
- System information (cPanel version, Ubuntu version)
- Relevant logs from `/var/log/hyperspeed_pro/`
- Screenshots if applicable

**Use this template:**
```markdown
**Environment:**
- OS: Ubuntu 22.04/24.04
- cPanel Version: X.X.X
- HyperSpeed Pro Version: X.X.X

**Steps to Reproduce:**
1. First step
2. Second step
3. ...

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Logs:**
```
[Paste relevant logs here]
```

**Screenshots:**
[If applicable]
```

### Requesting Features

**Feature requests should include:**
- Clear use case explaining why this feature is needed
- Detailed description of desired functionality
- Potential implementation approach (if you have ideas)
- Impact on existing features

### Improving Documentation

Documentation improvements are always welcome!

**Areas that need documentation:**
- Installation guides
- Configuration examples
- Troubleshooting tips
- Best practices
- API documentation
- Video tutorials

---

## Development Setup

### Local Development Environment

1. **Set up test server:**
   ```bash
   # Ubuntu 22.04 or 24.04 VM/Container
   # Install cPanel/WHM (development license)
   ```

2. **Clone repository:**
   ```bash
   git clone https://github.com/Ferguson230/Hyperspeed-Pro.git
   cd hyperspeed-pro
   ```

3. **Install in development mode:**
   ```bash
   cd hyperspeed-pro
   bash install.sh
   ```

4. **Make changes and test:**
   ```bash
   # Edit files
   # Test changes
   # Run verification
   bash verify-installation.sh
   ```

### Project Structure

```
hyperspeed-pro/
├── lib/                    # Core engine libraries (PHP)
│   ├── PerformanceEngine.php
│   └── SecurityEngine.php
├── cgi/                    # WHM interface (Perl CGI)
│   └── index.cgi
├── config/                 # Configuration templates
│   └── nginx-hyperspeed.conf
├── bin/                    # Command-line tools
│   ├── hyperspeed
│   └── benchmark.sh
└── assets/                 # Frontend assets
    ├── style.css
    └── dashboard.js

hyperspeed-pro-cpanel/
├── uapi/                   # cPanel UAPI module (Perl)
│   └── HyperSpeed.pm
├── cpanel-interface/       # User interface
│   ├── index.html
│   └── assets/
└── lib/                    # Sync service
    └── sync-users.php
```

---

## Coding Standards

### PHP Code Standards

Follow **PSR-12** coding standard:

```php
<?php
/**
 * Class description
 * 
 * @package HyperSpeed Pro
 */
class PerformanceEngine
{
    /**
     * Method description
     * 
     * @param string $key Cache key
     * @return mixed Cached value or false
     */
    public function get(string $key)
    {
        // Method implementation
    }
}
```

**Requirements:**
- Type hints for parameters and return types
- PHPDoc comments for all classes and methods
- Proper error handling with try-catch
- Input validation and sanitization
- Use strict types: `declare(strict_types=1);`

### Perl Code Standards

Follow **Perl Best Practices**:

```perl
package Cpanel::API::HyperSpeed;

use strict;
use warnings;

sub get_status {
    my $self = shift;
    
    # Implementation
    
    return {
        status => 1,
        message => 'Success',
    };
}
```

**Requirements:**
- Always use `strict` and `warnings`
- Clear variable names
- Comments for complex logic
- Proper error handling with eval/die
- Return structured data (hashrefs)

### JavaScript Code Standards

Follow **ES6+ standards**:

```javascript
/**
 * Load dashboard data from UAPI
 */
async function loadDashboardData() {
    try {
        const response = await fetch('/execute/HyperSpeed/get_status');
        const data = await response.json();
        
        if (data.status === 1) {
            updateDashboard(data.result);
        }
    } catch (error) {
        showToast('Error loading data', 'error');
    }
}
```

**Requirements:**
- Use `const` and `let`, not `var`
- Async/await for asynchronous operations
- Arrow functions where appropriate
- JSDoc comments for functions
- Proper error handling

### Bash Script Standards

```bash
#!/bin/bash
# Script description
# Usage: ./script.sh [options]

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# Functions should have descriptive names
function install_dependencies() {
    echo -e "${GREEN}Installing dependencies...${NC}"
    # Implementation
}
```

**Requirements:**
- Always use `set -e` for safety
- Check for root/permissions
- Validate inputs
- Provide clear error messages
- Use functions for reusable code

---

## Testing Guidelines

### Manual Testing Checklist

Before submitting changes, test:

**WHM Plugin:**
- [ ] Installation completes without errors
- [ ] WHM dashboard loads correctly
- [ ] All metrics display properly
- [ ] Cache flush works
- [ ] Security settings apply
- [ ] Services start/stop correctly
- [ ] Uninstallation cleans up properly

**cPanel Plugin:**
- [ ] UAPI endpoints respond correctly
- [ ] Dashboard loads in cPanel
- [ ] Domain list displays
- [ ] Cache clearing works
- [ ] Bypass rules save/load
- [ ] Security exemptions work
- [ ] Sync with WHM functions

**Performance Testing:**
```bash
# Run benchmark
/usr/local/bin/hyperspeed benchmark:run

# Check cache hit rate
redis-cli INFO stats | grep keyspace_hits

# Monitor service health
systemctl status hyperspeed-engine hyperspeed-cpanel-sync
```

### Verification Script

Always run before committing:
```bash
bash verify-installation.sh
```

### Security Testing

- Test with hostile inputs (SQL injection, XSS)
- Verify rate limiting works
- Test DDoS protection triggers
- Ensure domain ownership validation
- Check file permission security

---

## Submission Process

### 1. Prepare Your Changes

```bash
# Update from upstream
git fetch upstream
git rebase upstream/main

# Run tests
bash verify-installation.sh

# Check code style
# (run any linters)
```

### 2. Commit Your Changes

Use clear, descriptive commit messages:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code formatting (no functional changes)
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```bash
git commit -m "feat(cache): Add Zstandard compression support

Implement Zstandard compression as an alternative to Brotli
for improved performance on older CPUs.

Closes #123"
```

```bash
git commit -m "fix(security): Prevent SQL injection in bypass rules

Add input validation and escaping for user-provided
bypass rule patterns.

Fixes #456"
```

### 3. Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub:

1. Go to your fork on GitHub
2. Click "New Pull Request"
3. Select your feature branch
4. Fill in PR template (see below)
5. Submit for review

### Pull Request Template

```markdown
## Description
[Describe what changes this PR introduces]

## Motivation and Context
[Why is this change needed? What problem does it solve?]

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Testing
[Describe the tests you ran to verify your changes]

- [ ] Tested on Ubuntu 22.04
- [ ] Tested on Ubuntu 24.04
- [ ] Tested with cPanel 11.110+
- [ ] Ran verify-installation.sh
- [ ] Checked for performance impact

## Screenshots (if applicable)
[Add screenshots here]

## Checklist
- [ ] My code follows the project's coding standards
- [ ] I have commented my code, particularly in complex areas
- [ ] I have updated relevant documentation
- [ ] My changes generate no new warnings or errors
- [ ] I have tested on a clean installation
- [ ] I have tested the uninstallation process

## Related Issues
Closes #[issue number]
```

### 4. Code Review Process

- Maintainers will review your PR
- Address any requested changes
- Once approved, maintainers will merge

**Review criteria:**
- Code quality and style
- Functionality and correctness
- Performance impact
- Security implications
- Documentation completeness
- Test coverage

---

## Development Guidelines

### Performance Considerations

- **Cache Efficiency**: Always test cache hit rates
- **Memory Usage**: Monitor Redis/Memcached consumption
- **Database Queries**: Minimize database calls
- **File I/O**: Use caching for frequent file reads

### Security Best Practices

- **Input Validation**: Sanitize all user inputs
- **XSS Prevention**: Escape HTML output
- **SQL Injection**: Use parameterized queries
- **CSRF Protection**: Implement token validation
- **File Permissions**: Set restrictive permissions (644/755)

### Compatibility

Ensure compatibility with:
- cPanel/WHM 11.110+
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- PHP 8.0+
- Redis 6.0+
- Nginx 1.18+

---

## Recognition

Contributors will be:
- Listed in CHANGELOG.md
- Credited in release notes
- Added to CONTRIBUTORS.md file

---

## Questions?

- **Forum**: https://community.hyperspeed.pro
- **Discord**: https://discord.gg/hyperspeed
- **Email**: dev@hyperspeed.pro

---

## License

By contributing to HyperSpeed Pro, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to HyperSpeed Pro!** Your efforts help make web hosting faster for everyone. 🚀
