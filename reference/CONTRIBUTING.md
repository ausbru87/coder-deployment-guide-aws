# Contributing to Coder AWS Deployment

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone git@github.com:YOUR_USERNAME/coder-aws-deploy.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes thoroughly
6. Submit a pull request

## Development Guidelines

### Terraform Code

- Run `terraform fmt -recursive` before committing
- Validate with `terraform validate`
- Use meaningful variable names (lowerCamelCase)
- Add comments for complex logic
- Keep modules focused and reusable

### Documentation

- Update documentation for any user-facing changes
- Use clear, concise language
- Include code examples where helpful
- Follow existing documentation structure

### Commit Messages

Follow Conventional Commits format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(eks): add support for graviton instances
fix(aurora): correct min ACU validation
docs(sr-ha): update capacity planning guide
```

## Pull Request Process

1. **Update documentation** if your changes affect users
2. **Add tests** if applicable
3. **Run `terraform fmt`** on all changed files
4. **Include `terraform plan` output** for infrastructure changes
5. **Reference related issues** in PR description
6. **Request review** from maintainers

## Testing

Before submitting:

1. Validate Terraform: `terraform validate`
2. Check formatting: `terraform fmt -check -recursive`
3. Test in a sandbox environment if possible
4. Document any manual testing performed

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions.

## Questions?

Open an issue or reach out to maintainers.

---

Thank you for contributing! 🎉
