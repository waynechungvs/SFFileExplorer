# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Salesforce DX (SFDX) project for developing on the Salesforce platform. It uses Apex for server-side logic and Lightning Web Components (LWC) for the frontend.

- **Platform**: Salesforce Developer Edition
- **API Version**: 64.0
- **Languages**: Apex, JavaScript (LWC), HTML, CSS
- **Main Source Directory**: `/force-app/main/default/`

## Essential Commands

### Development Setup

```bash
# Authenticate with a Salesforce org
sf org login web -d -a DevHub

# Create a scratch org
sf org create scratch -f config/project-scratch-def.json -a MyScratchOrg -d -y 30

# Push source to scratch org
sf project deploy start

# Pull changes from scratch org
sf project retrieve start
```

### Code Quality

```bash
# Run ESLint on all Aura and LWC JavaScript files
npm run lint

# Format all code files with Prettier
npm run prettier

# Verify formatting without making changes
npm run prettier:verify
```

### Testing

```bash
# Run all LWC unit tests
npm test

# Run tests in watch mode for development
npm run test:unit:watch

# Run tests with debugging enabled
npm run test:unit:debug

# Run tests with coverage report
npm run test:unit:coverage

# Run Apex tests in the org
sf apex test run -l RunLocalTests -w 10
```

### Common Development Tasks

```bash
# Open the org in browser
sf org open

# Execute anonymous Apex
sf apex run -f scripts/apex/hello.apex

# Run a SOQL query
sf data query -q "SELECT Id, Name FROM Account LIMIT 10"

# View real-time debug logs
sf apex log tail --color

# Deploy specific metadata
sf project deploy start -m ApexClass:MyClass,LightningComponentBundle:myComponent
```

## Architecture Overview

### Directory Structure

- `/force-app/main/default/`: All Salesforce metadata
  - `aura/`: Aura components (legacy Lightning components)
  - `classes/`: Apex classes and their test classes
  - `lwc/`: Lightning Web Components
  - `objects/`: Custom objects, fields, and relationships
  - `triggers/`: Apex triggers
  - `permissionsets/`: Permission sets for access control
  - `flexipages/`: Lightning page configurations
  - `applications/`: Custom app definitions

### Development Patterns

1. **Apex Classes**: Follow the pattern of having a corresponding test class for each Apex class (e.g., `MyClass.cls` and `MyClassTest.cls`)
2. **LWC Components**: Each component should have its folder containing `.js`, `.html`, `.css`, and `.js-meta.xml` files
3. **Triggers**: Keep triggers minimal, delegating logic to handler classes
4. **Test Coverage**: Maintain at least 75% code coverage for Apex (Salesforce requirement)

### Pre-commit Hooks

The project uses Husky and lint-staged to automatically:

1. Format code with Prettier
2. Lint JavaScript files with ESLint
3. Run related LWC tests for changed components

### Scratch Org Configuration

Defined in `config/project-scratch-def.json`:

- Edition: Developer
- Features: EnableSetPasswordInApi
- Settings: Lightning Experience enabled

## Important Notes

- Always pull latest changes before starting development: `sf project retrieve start`
- Run tests before pushing changes to ensure nothing is broken
- Use scratch orgs for development, not production or sandbox orgs directly
- The project follows Salesforce DX source format (not metadata format)
