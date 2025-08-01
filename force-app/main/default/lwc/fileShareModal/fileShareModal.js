import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getActiveUsers from "@salesforce/apex/OrgFileExplorerController.getActiveUsers";
import shareWithUser from "@salesforce/apex/OrgFileExplorerController.shareWithUser";

export default class FileShareModal extends LightningElement {
  @api fileId;
  @api fileName;
  
  selectedUserId = "";
  users = [];
  isLoading = false;

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

  handleShare() {
    if (!this.selectedUserId) {
      this.showToast("Warning", "Please select a user to share with", "warning");
      return;
    }

    this.isLoading = true;
    shareWithUser({ contentDocumentId: this.fileId, userId: this.selectedUserId })
      .then(() => {
        this.showToast("Success", "File shared successfully", "success");
        this.handleClose();
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

  handleClose() {
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

  get hasFileId() {
    return this.fileId != null;
  }

  get userOptions() {
    return [
      { label: "Select a user...", value: "" },
      ...this.users
    ];
  }
}