# Contributing to PowerDNS Operations Collection

We welcome contributions to the PowerDNS Operations Collection! This document provides guidelines for contributing to this project.

## 🤝 How to Contribute

### Reporting Issues

1. **Search existing issues** first to avoid duplicates
2. **Use issue templates** when available
3. **Provide detailed information** including:
   - Operating system and version
   - Ansible version
   - PowerDNS version
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant logs or error messages

### Submitting Pull Requests

1. **Fork the repository** and create a feature branch
2. **Follow coding standards** (see below)
3. **Add tests** for new functionality
4. **Update documentation** as needed
5. **Ensure CI passes** before submitting
6. **Write clear commit messages**

## 🛠️ Development Setup

### Prerequisites

- Python 3.8+
- Ansible 2.9+
- Docker (for Molecule testing)
- Git

### Local Development

```bash
# Clone your fork
git clone https://github.com/your-username/community.powerdns_ops.git
cd community.powerdns_ops

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install development dependencies
pip install -r requirements-dev.txt

# Install pre-commit hooks
pre-commit install
```

### Running Tests

```bash
# Lint code
yamllint .
ansible-lint

# Run syntax checks
ansible-playbook --syntax-check powerdns-operational-playbook.yml

# Run Molecule tests
molecule test

# Run specific scenario
molecule test -s security
```

## 📝 Coding Standards

### Ansible Best Practices

- **Use descriptive task names**
- **Add comments for complex logic**
- **Use proper YAML formatting**
- **Follow Ansible naming conventions**
- **Use tags appropriately**
- **Handle errors gracefully**

### YAML Style

```yaml
# Good
- name: Install PowerDNS packages
  package:
    name: "{{ item }}"
    state: present
  loop:
    - pdns-server
    - pdns-backend-mysql

# Bad
- package: name={{ item }} state=present
  with_items:
  - pdns-server
  - pdns-backend-mysql
```

### Variable Naming

- Use `snake_case` for variables
- Prefix role-specific variables with role name
- Use descriptive names

```yaml
# Good
powerdns_api_key: "secret-key"
mysql_root_password: "secure-password"

# Bad
api_key: "secret-key"
pwd: "secure-password"
```

### Template Guidelines

- Use meaningful variable names
- Add comments for complex logic
- Follow Jinja2 best practices
- Handle undefined variables gracefully

```jinja2
{# Good #}
{% if powerdns_api_enabled | default(false) %}
api=yes
api-key={{ powerdns_api_key }}
{% endif %}

{# Bad #}
{% if api %}
api=yes
api-key={{ key }}
{% endif %}
```

## 🧪 Testing Guidelines

### Test Coverage

All contributions should include appropriate tests:

- **Unit tests** for individual tasks
- **Integration tests** for complete workflows
- **Molecule scenarios** for different configurations
- **Documentation updates** for new features

### Molecule Scenarios

We maintain several test scenarios:

- `default` - Basic PowerDNS setup
- `security` - Security-hardened deployment
- `ha_cluster` - High availability cluster
- `dnssec` - DNSSEC-enabled setup

### Adding New Tests

```bash
# Create new scenario
molecule init scenario new_feature

# Edit molecule.yml and verify.yml
# Add test cases in tests/

# Run new scenario
molecule test -s new_feature
```

## 📚 Documentation

### Documentation Standards

- **Update README** for new features
- **Add role documentation** in `roles/*/README.md`
- **Include examples** for complex configurations
- **Update CHANGELOG** for releases

### Documentation Format

Use clear, concise language with:

- **Code examples** for configuration
- **Step-by-step instructions** for procedures
- **Troubleshooting sections** for common issues
- **Links to external resources** when helpful

## 🔄 Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** - Breaking changes
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes (backward compatible)

### Release Checklist

1. Update version in `galaxy.yml`
2. Update `CHANGELOG.md`
3. Run full test suite
4. Create release PR
5. Tag release after merge
6. Publish to Ansible Galaxy

## 🏷️ Issue and PR Labels

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed

### PR Labels

- `breaking-change` - Breaking changes
- `feature` - New features
- `bugfix` - Bug fixes
- `documentation` - Documentation updates
- `dependencies` - Dependency updates

## 🎯 Feature Requests

When requesting new features:

1. **Check existing issues** first
2. **Describe the use case** clearly
3. **Provide examples** if possible
4. **Consider implementation** complexity
5. **Be open to discussion** and alternatives

## 🐛 Bug Reports

For effective bug reports:

1. **Use the bug report template**
2. **Provide minimal reproduction** steps
3. **Include environment details**
4. **Add relevant logs** or error messages
5. **Test with latest version** first

## 💬 Communication

### Channels

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - General questions and ideas
- **Pull Requests** - Code contributions and reviews

### Code of Conduct

Please note that this project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## 🙏 Recognition

Contributors are recognized in:

- **CONTRIBUTORS.md** file
- **Release notes** for significant contributions
- **GitHub contributors** page

## 📞 Getting Help

If you need help:

1. **Check the documentation** first
2. **Search existing issues** and discussions
3. **Ask in GitHub Discussions** for general questions
4. **Open an issue** for specific problems

Thank you for contributing to the PowerDNS Operations Collection! 🎉
