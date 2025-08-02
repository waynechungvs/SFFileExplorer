# Salesforce File Explorer

A comprehensive Salesforce Lightning Web Component application for managing and exploring files across your Salesforce organization.

## Features

- **File Browsing**: Browse and search files throughout your Salesforce org
- **Advanced Filtering**: Filter by file type, owner, creation date, and more
- **Bulk Operations**: Select and manage multiple files simultaneously
- **File Sharing**: Share files with users and manage sharing permissions
- **File Preview**: Preview supported file types directly in the interface
- **Connection Management**: View and manage file connections and relationships
- **Ownership Management**: Transfer file ownership between users
- **Pagination**: Efficiently navigate through large file collections

## Components

### Lightning Web Components

- **orgFileExplorer**: Main application component
- **fileList**: Displays files in a structured list format
- **fileCard**: Individual file display component
- **fileToolbar**: Action toolbar for file operations
- **fileFilterSidebar**: Advanced filtering controls
- **paginationControls**: Navigation controls for large datasets

### Modal Components

- **filePreviewModal**: Preview files without downloading
- **fileShareModal**: Manage individual file sharing
- **bulkShareModal**: Share multiple files at once
- **fileConnectionsModal**: View file relationships and connections
- **fileOwnershipModal**: Transfer file ownership

### Apex Classes

- **OrgFileExplorerController**: Server-side logic for file operations and data retrieval

## Development Setup

### Prerequisites

- Salesforce CLI installed
- Node.js and npm
- Access to a Salesforce Developer Edition or Scratch Org

### Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd SFFileExplorer

# Install dependencies
npm install

# Authenticate with Salesforce
sf org login web -d -a DevHub

# Create a scratch org (optional)
sf org create scratch -f config/project-scratch-def.json -a MyScratchOrg -d -y 30

# Deploy to your org
sf project deploy start
```

### Development Commands

```bash
# Format code
npm run prettier

# Lint JavaScript files
npm run lint

# Run unit tests
npm test

# Run tests in watch mode
npm run test:unit:watch

# Run tests with coverage
npm run test:unit:coverage
```

### Salesforce Commands

```bash
# Deploy to org
sf project deploy start

# Pull changes from org
sf project retrieve start

# Open org in browser
sf org open

# Run Apex tests
sf apex test run -l RunLocalTests -w 10
```

## Usage

1. Deploy the components to your Salesforce org
2. Add the `orgFileExplorer` component to a Lightning page
3. Configure component properties as needed:
   - `pageSize`: Number of files to display per page (default: 25)
   - `showOrphanedOnly`: Show only orphaned files (default: false)

## Configuration

The project uses standard Salesforce DX structure:

- API Version: 64.0
- Source format (not metadata format)
- Lightning Experience enabled
- Developer Edition features

## Contributing

1. Follow the existing code style and patterns
2. Run tests before committing: `npm test`
3. Use the pre-commit hooks for code formatting
4. Maintain at least 75% test coverage for Apex code

## Resources

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Lightning Web Components Documentation](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
