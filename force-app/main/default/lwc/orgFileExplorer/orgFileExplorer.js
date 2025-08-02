import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getOrgFiles from "@salesforce/apex/OrgFileExplorerController.getOrgFiles";
import deleteFiles from "@salesforce/apex/OrgFileExplorerController.deleteFiles";
import getFileTypes from "@salesforce/apex/OrgFileExplorerController.getFileTypes";
import getFileOwners from "@salesforce/apex/OrgFileExplorerController.getFileOwners";

export default class OrgFileExplorer extends LightningElement {
  // Public properties (configurable)
  @api pageSize = 25;
  @api showOrphanedOnly = false;

  // Private reactive properties
  @track searchTerm = "";
  @track filters = {};
  @track pageNumber = 1;
  @track sortBy = "CreatedDate";
  @track sortDirection = "DESC";
  @track selectedFiles = [];
  @track showPreviewModal = false;
  @track previewFileId = null;
  @track showShareModal = false;
  @track shareFileId = null;
  @track shareFileName = "";
  @track showBulkShareModal = false;
  @track showConnectionsModal = false;
  @track connectionsFileId = null;
  @track connectionsFileName = "";
  @track showOwnershipModal = false;
  @track ownershipFileId = null;
  @track ownershipFileName = "";
  @track ownershipCurrentOwner = "";
  @track files = [];
  @track totalCount = 0;
  @track isLoading = false;
  @track error = null;
  @track fileTypes = [];
  @track fileOwners = [];
  @track showFilters = true;

  @track viewMode = "card"; // 'card' or 'list'

  pageSizeOptions = [
    { label: "25", value: 25 },
    { label: "50", value: 50 },
    { label: "100", value: 100 }
  ];

  sortOptions = [
    { label: "Created Date", value: "CreatedDate" },
    { label: "Modified Date", value: "LastModifiedDate" },
    { label: "File Name", value: "Title" },
    { label: "File Size", value: "ContentSize" },
    { label: "Created By", value: "CreatedBy.Name" }
  ];

  @wire(getFileTypes)
  wiredFileTypes({ error, data }) {
    if (data) {
      this.fileTypes = data;
    } else if (error) {
      console.error("Error loading file types:", error);
    }
  }

  @wire(getFileOwners)
  wiredFileOwners({ error, data }) {
    if (data) {
      this.fileOwners = data;
    } else if (error) {
      console.error("Error loading file owners:", error);
    }
  }

  connectedCallback() {
    // Apply initial filter if showOrphanedOnly is set
    if (this.showOrphanedOnly) {
      this.filters = { ...this.filters, showOrphaned: true };
    }
    this.loadFiles();
  }

  loadFiles() {
    this.isLoading = true;
    this.error = null;

    getOrgFiles({
      searchTerm: this.searchTerm,
      filters: this.filters,
      pageNumber: this.pageNumber,
      pageSize: parseInt(this.pageSize, 10),
      sortBy: this.sortBy,
      sortDirection: this.sortDirection
    })
      .then((result) => {
        this.files = result.files || [];
        this.totalCount = result.totalCount || 0;
        this.pageNumber = result.pageNumber || 1;
        this.selectedFiles = [];
        this.error = null;
      })
      .catch((error) => {
        this.error = error.body ? error.body.message : error.message;
        this.files = [];
        this.totalCount = 0;
        this.showToast("Error", this.error, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleSearch(event) {
    this.searchTerm = event.detail.searchTerm;
    this.pageNumber = 1;
    this.loadFiles();
  }

  handleFilterChange(event) {
    this.filters = event.detail.filters;
    console.log("Main component received filters:", this.filters); // Debug log
    this.pageNumber = 1;
    this.loadFiles();
  }

  handleSort(event) {
    const { sortBy, sortDirection } = event.detail;
    this.sortBy = sortBy;
    this.sortDirection = sortDirection;
    this.loadFiles();
  }

  handlePageChange(event) {
    this.pageNumber = event.detail.pageNumber;
    this.loadFiles();
  }

  handlePageSizeChange(event) {
    this.pageSize = event.detail.pageSize;
    this.pageNumber = 1;
    this.loadFiles();
  }

  handleFileSelection(event) {
    const { fileId, isSelected } = event.detail;
    if (isSelected) {
      this.selectedFiles = [...this.selectedFiles, fileId];
    } else {
      this.selectedFiles = this.selectedFiles.filter((id) => id !== fileId);
    }
  }

  handleSelectAll(event) {
    if (event.detail.isSelected) {
      this.selectedFiles = this.files.map((file) => file.contentDocumentId);
    } else {
      this.selectedFiles = [];
    }
  }

  handleBulkAction(event) {
    const action = event.detail.action;

    if (this.selectedFiles.length === 0) {
      this.showToast("Warning", "Please select at least one file", "warning");
      return;
    }

    switch (action) {
      case "delete":
        this.handleBulkDelete();
        break;
      case "download":
        this.handleBulkDownload();
        break;
      case "bulkshare":
        this.handleBulkShareAction();
        break;
      case "bulkchangeowner":
        this.handleBulkChangeOwnerAction();
        break;
      default:
        break;
    }
  }

  handleBulkDelete() {
    // Use a custom confirmation modal instead of native confirm
    const confirmMessage = `Are you sure you want to delete ${this.selectedFiles.length} file(s)?`;
    // For now, proceed without confirmation - in production, implement a proper modal
    this.showToast("Info", confirmMessage, "info");

    this.isLoading = true;
    deleteFiles({ contentDocumentIds: this.selectedFiles })
      .then(() => {
        this.showToast(
          "Success",
          `${this.selectedFiles.length} file(s) deleted successfully`,
          "success"
        );
        this.selectedFiles = [];
        this.loadFiles();
      })
      .catch((error) => {
        this.showToast(
          "Error",
          error.body ? error.body.message : error.message,
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleBulkDownload() {
    this.selectedFiles.forEach((fileId) => {
      const file = this.files.find((f) => f.contentDocumentId === fileId);
      if (file && file.downloadUrl) {
        window.open(file.downloadUrl, "_blank");
      }
    });
  }

  handleFilePreview(event) {
    this.previewFileId = event.detail.fileId;
    this.showPreviewModal = true;
  }

  handleClosePreview() {
    this.showPreviewModal = false;
    this.previewFileId = null;
  }

  handleFileShare(event) {
    const fileId = event.detail.fileId;
    const file = this.files.find(f => f.contentDocumentId === fileId);
    this.shareFileId = fileId;
    this.shareFileName = file ? file.fileName : "Unknown File";
    this.showShareModal = true;
  }

  handleCloseShare() {
    this.showShareModal = false;
    this.shareFileId = null;
    this.shareFileName = "";
  }

  handleBulkShareAction() {
    if (this.selectedFiles.length === 0) {
      this.showToast("Warning", "Please select at least one file", "warning");
      return;
    }
    this.showBulkShareModal = true;
  }

  handleCloseBulkShare() {
    this.showBulkShareModal = false;
    // Reload files to refresh the data after sharing
    this.selectedFiles = [];
    this.loadFiles();
  }

  handleViewConnections(event) {
    const { fileId, fileName } = event.detail;
    console.log('OrgFileExplorer: handleViewConnections called with:', { fileId, fileName });
    this.connectionsFileId = fileId;
    this.connectionsFileName = fileName;
    this.showConnectionsModal = true;
    console.log('OrgFileExplorer: Modal properties set - connectionsFileId:', this.connectionsFileId, 'showConnectionsModal:', this.showConnectionsModal);
  }

  handleCloseConnections() {
    this.showConnectionsModal = false;
    this.connectionsFileId = null;
    this.connectionsFileName = "";
  }

  handleChangeOwner(event) {
    const { fileId, fileName, currentOwnerName } = event.detail;
    this.ownershipFileId = fileId;
    this.ownershipFileName = fileName;
    this.ownershipCurrentOwner = currentOwnerName;
    this.showOwnershipModal = true;
  }

  handleBulkChangeOwnerAction() {
    if (this.selectedFiles.length === 0) {
      this.showToast("Warning", "Please select at least one file", "warning");
      return;
    }
    // For bulk, we don't set individual file details
    this.ownershipFileId = null;
    this.ownershipFileName = null;
    this.ownershipCurrentOwner = "Multiple Owners";
    this.showOwnershipModal = true;
  }

  handleCloseOwnership() {
    this.showOwnershipModal = false;
    this.ownershipFileId = null;
    this.ownershipFileName = null;
    this.ownershipCurrentOwner = "";
    // Reload files to refresh the data after ownership change
    this.selectedFiles = [];
    this.loadFiles();
  }

  handleViewModeChange(event) {
    this.viewMode = event.detail.viewMode;
  }

  toggleFilters() {
    this.showFilters = !this.showFilters;
  }

  showToast(title, message, variant) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(evt);
  }

  get hasFiles() {
    return this.files && this.files.length > 0;
  }

  get noFilesMessage() {
    if (this.searchTerm || Object.keys(this.filters).length > 0) {
      return "No files found matching your criteria.";
    }
    return "No files found in the organization.";
  }

  get selectedCount() {
    return this.selectedFiles.length;
  }

  get filterButtonLabel() {
    return this.showFilters ? "Hide Filters" : "Show Filters";
  }

  get mainContainerClass() {
    return `main-container ${this.showFilters ? "" : "full-width"}`;
  }
}
