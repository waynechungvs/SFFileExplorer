import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFileConnections from "@salesforce/apex/OrgFileExplorerController.getFileConnections";

export default class FileConnectionsModal extends LightningElement {
  @api fileId;
  @api fileName;
  @api showModal = false;
  
  connections = [];
  isLoading = false;
  error = null;

  connectedCallback() {
    if (this.showModal && this.fileId) {
      this.loadConnections();
    }
  }

  // Load connections when fileId changes
  @api
  async loadConnections() {
    if (!this.fileId) return;
    
    this.isLoading = true;
    this.error = null;
    
    try {
      const rawConnections = await getFileConnections({ contentDocumentId: this.fileId });
      // Process connections to add computed properties
      this.connections = rawConnections.map(conn => ({
        ...conn,
        shareTypeLabel: this.getShareTypeLabel(conn.shareType)
      }));
    } catch (error) {
      this.error = error.body ? error.body.message : error.message;
      console.error("Error loading file connections:", error);
    } finally {
      this.isLoading = false;
    }
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleOpenConnection(event) {
    const url = event.currentTarget.dataset.url;
    const entityName = event.currentTarget.dataset.entityName;
    
    if (url) {
      // Open in same tab for Salesforce URLs, new tab for external URLs
      if (url.startsWith('/') || url.includes(window.location.hostname)) {
        window.location.href = url;
      } else {
        window.open(url, '_blank');
      }
      
      this.showToast(
        "Success", 
        `Opening ${entityName}`, 
        "success"
      );
    }
  }

  showToast(title, message, variant) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(evt);
  }

  get hasConnections() {
    return !this.isLoading && !this.error && this.connections && this.connections.length > 0;
  }

  get hasNoConnections() {
    return !this.isLoading && !this.error && (!this.connections || this.connections.length === 0);
  }

  get connectionCount() {
    return this.connections ? this.connections.length : 0;
  }

  get connectionCountPlural() {
    return this.connectionCount === 1 ? '' : 's';
  }

  // Helper to get share type label
  getShareTypeLabel(shareType) {
    const shareTypeMap = {
      'V': 'Viewer',
      'C': 'Collaborator', 
      'I': 'Inferred'
    };
    return shareTypeMap[shareType] || shareType;
  }

  get shareTypeLabel() {
    // This getter is used in the template but we need individual labels per connection
    // We'll handle this in the template using data attributes
    return '';
  }
}