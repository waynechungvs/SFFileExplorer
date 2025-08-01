import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getActiveUsers from "@salesforce/apex/OrgFileExplorerController.getActiveUsers";
import bulkShareWithUser from "@salesforce/apex/OrgFileExplorerController.bulkShareWithUser";

export default class BulkShareModal extends LightningElement {
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

  async handleBulkShare() {
    if (!this.selectedUserId) {
      this.showToast("Warning", "Please select a user to share with", "warning");
      return;
    }

    if (!this.selectedFileIds || this.selectedFileIds.length === 0) {
      this.showToast("Warning", "No files selected for sharing", "warning");
      return;
    }

    this.isLoading = true;
    this.isProcessing = true;
    this.processingStatus = true;
    this.processedCount = 0;

    try {
      // Process in batches of 10 to avoid limits
      const batchSize = 10;
      const totalFiles = this.selectedFileIds.length;
      
      for (let i = 0; i < totalFiles; i += batchSize) {
        const batch = this.selectedFileIds.slice(i, i + batchSize);
        
        await bulkShareWithUser({ 
          contentDocumentIds: batch, 
          userId: this.selectedUserId 
        });
        
        this.processedCount = Math.min(i + batchSize, totalFiles);
        
        // Small delay to prevent overwhelming the system
        await new Promise(resolve => setTimeout(resolve, 100));
      }

      this.showToast(
        "Success", 
        `Successfully shared ${totalFiles} files with the selected user`, 
        "success"
      );
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
      { label: "Select a user...", value: "" },
      ...this.users
    ];
  }

  get selectedFileCount() {
    return this.selectedFileIds ? this.selectedFileIds.length : 0;
  }

  get progressPercentage() {
    if (!this.selectedFileIds || this.selectedFileIds.length === 0) return 0;
    return Math.round((this.processedCount / this.selectedFileIds.length) * 100);
  }

  get progressStyle() {
    return `width: ${this.progressPercentage}%`;
  }

  get shareButtonLabel() {
    return this.isProcessing ? "Sharing..." : "Share Files";
  }
}