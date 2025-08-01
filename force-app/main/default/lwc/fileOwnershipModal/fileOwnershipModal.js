import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getActiveUsers from "@salesforce/apex/OrgFileExplorerController.getActiveUsers";
import reassignFileOwner from "@salesforce/apex/OrgFileExplorerController.reassignFileOwner";
import bulkReassignFileOwner from "@salesforce/apex/OrgFileExplorerController.bulkReassignFileOwner";

export default class FileOwnershipModal extends LightningElement {
  @api fileId;
  @api fileName;
  @api currentOwnerName;
  @api selectedFileIds = [];
  @api showModal = false;
  
  selectedUserId = "";
  users = [];
  isLoading = false;
  isProcessing = false;
  processingStatus = false;
  processedCount = 0;

  @wire(getActiveUsers)
  wiredUsers({ error, data }) {
    if (data) {
      this.users = data;
    } else if (error) {
      console.error("Error loading users:", error);
    }
  }

  handleUserChange(event) {
    this.selectedUserId = event.detail.value;
  }

  async handleTransferOwnership() {
    if (!this.selectedUserId) {
      this.showToast("Warning", "Please select a new owner", "warning");
      return;
    }

    // Confirm the action
    const confirmMessage = this.isSingleFile 
      ? `Are you sure you want to transfer ownership of "${this.fileName}" to the selected user?`
      : `Are you sure you want to transfer ownership of ${this.selectedFileCount} files to the selected user?`;
    
    if (!confirm(confirmMessage)) {
      return;
    }

    this.isLoading = true;
    this.isProcessing = true;
    this.processedCount = 0;

    try {
      if (this.isSingleFile) {
        // Single file transfer
        await reassignFileOwner({ 
          contentDocumentId: this.fileId, 
          newOwnerId: this.selectedUserId 
        });
        
        this.showToast(
          "Success", 
          `Successfully transferred ownership of "${this.fileName}"`, 
          "success"
        );
      } else {
        // Bulk file transfer with progress tracking
        this.processingStatus = true;
        const batchSize = 10;
        const totalFiles = this.selectedFileIds.length;
        
        for (let i = 0; i < totalFiles; i += batchSize) {
          const batch = this.selectedFileIds.slice(i, i + batchSize);
          
          await bulkReassignFileOwner({ 
            contentDocumentIds: batch, 
            newOwnerId: this.selectedUserId 
          });
          
          this.processedCount = Math.min(i + batchSize, totalFiles);
          
          // Small delay to show progress
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        
        this.showToast(
          "Success", 
          `Successfully transferred ownership of ${totalFiles} files`, 
          "success"
        );
      }

      // Close modal and refresh data
      this.handleClose();
      
    } catch (error) {
      this.showToast(
        "Error",
        error.body ? error.body.message : error.message,
        "error"
      );
    } finally {
      this.isLoading = false;
      this.isProcessing = false;
      this.processingStatus = false;
      this.processedCount = 0;
    }
  }

  handleClose() {
    this.selectedUserId = "";
    this.processingStatus = false;
    this.processedCount = 0;
    this.dispatchEvent(new CustomEvent("close"));
  }

  showToast(title, message, variant) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(evt);
  }

  get userOptions() {
    return [
      { label: "Select a new owner...", value: "" },
      ...this.users
    ];
  }

  get isSingleFile() {
    return this.fileId != null && this.fileName != null;
  }

  get selectedFileCount() {
    return this.selectedFileIds ? this.selectedFileIds.length : 0;
  }

  get modalTitle() {
    return this.isSingleFile ? "Transfer File Ownership" : "Bulk Transfer Ownership";
  }

  get modalSubtitle() {
    return this.isSingleFile 
      ? "Transfer ownership of this file to another user"
      : `Transfer ownership of ${this.selectedFileCount} files to another user`;
  }

  get fileText() {
    return this.isSingleFile ? "this file" : "these files";
  }

  get progressPercentage() {
    if (!this.selectedFileIds || this.selectedFileIds.length === 0) return 0;
    return Math.round((this.processedCount / this.selectedFileIds.length) * 100);
  }

  get progressStyle() {
    return `width: ${this.progressPercentage}%`;
  }

  get transferButtonLabel() {
    return this.isProcessing ? "Transferring..." : "Transfer Ownership";
  }
}