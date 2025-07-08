# Contributing to OpenSearch Performance and Resilience Testing Framework

Thank you for your interest in contributing to the OpenSearch Performance and Resilience Testing Framework! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

This project adheres to the [OpenSearch Community Code of Conduct](https://opensearch.org/codeofconduct.html). By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Bugs

If you find a bug in the project:

1. Check if the bug has already been reported in the project's issue tracker.
2. If not, create a new issue with a clear title and description.
3. Include as much relevant information as possible:
   - Steps to reproduce the bug
   - Expected behavior
   - Actual behavior
   - Environment details (OS, AWS region, OpenSearch version, etc.)
   - Screenshots or logs if applicable

### Suggesting Enhancements

If you have ideas for enhancements:

1. Check if the enhancement has already been suggested in the project's issue tracker.
2. If not, create a new issue with a clear title and description.
3. Provide a clear and detailed explanation of the feature you'd like to see, why it's valuable, and how it should work.

### Pull Requests

1. Fork the repository.
2. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes and commit them with clear, descriptive commit messages.
4. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
5. Submit a pull request to the main repository.

#### Pull Request Guidelines

- Follow the coding style and conventions used in the project.
- Include tests for new features or bug fixes.
- Update documentation as needed.
- Keep pull requests focused on a single topic.
- Write clear commit messages.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/opensearch-benchmark.git
   cd opensearch-benchmark
   ```

2. Install dependencies:
   ```bash
   pip install opensearch-benchmark
   ```

3. Make sure you have AWS CLI installed and configured:
   ```bash
   aws configure
   ```

## Testing

Before submitting a pull request, please test your changes:

1. Test CloudFormation templates:
   ```bash
   aws cloudformation validate-template --template-body file://templates/opensearch-benchmark-cfn.yaml
   aws cloudformation validate-template --template-body file://templates/opensearch-benchmark-dr.yaml
   ```

2. Test scripts locally if possible.

## Documentation

- Update the README.md file if your changes affect how users interact with the project.
- Comment your code where necessary, especially for complex logic.
- Update any relevant documentation in the docs directory.

## License

By contributing to this project, you agree that your contributions will be licensed under the project's [Apache License 2.0](LICENSE).

## Questions?

If you have any questions about contributing, please open an issue or reach out to the project maintainers.

Thank you for contributing to the OpenSearch Performance and Resilience Testing Framework!
