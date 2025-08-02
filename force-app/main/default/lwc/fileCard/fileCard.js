import { LightningElement, api } from "lwc";

export default class FileCard extends LightningElement {
  @api file;
  @api isSelected = false;

  handleCheckboxChange(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("fileselect", {
        detail: {
          fileId: this.file.contentDocumentId,
          isSelected: event.target.checked
        }
      })
    );
  }

  handleCardClick(event) {
    // Prevent card click when checkbox is clicked
    if (event.target.tagName !== "LIGHTNING-INPUT") {
      this.dispatchEvent(
        new CustomEvent("fileclick", {
          detail: { fileId: this.file.contentVersionId }
        })
      );
    }
  }

  handleShareClick(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("fileshare", {
        detail: { fileId: this.file.contentDocumentId }
      })
    );
  }

  handleLinksClick(event) {
    event.stopPropagation();
    console.log('FileCard: handleLinksClick called, this.file:', this.file);
    
    if (!this.file) {
      console.error('FileCard: this.file is undefined!');
      return;
    }
    
    const fileId = this.file.contentDocumentId;
    const fileName = this.file.fileName;
    console.log('FileCard: Dispatching viewconnections with fileId:', fileId, 'fileName:', fileName);
    
    this.dispatchEvent(
      new CustomEvent("viewconnections", {
        detail: { 
          fileId: fileId,
          fileName: fileName
        }
      })
    );
  }

  handleChangeOwnerClick(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("changeowner", {
        detail: { 
          fileId: this.file.contentDocumentId,
          fileName: this.file.fileName,
          currentOwnerName: this.file.currentOwner
        }
      })
    );
  }

  get fileIcon() {
    const fileTypeIconMap = {
      pdf: "doctype:pdf",
      doc: "doctype:word",
      docx: "doctype:word",
      xls: "doctype:excel",
      xlsx: "doctype:excel",
      ppt: "doctype:ppt",
      pptx: "doctype:ppt",
      txt: "doctype:txt",
      csv: "doctype:csv",
      xml: "doctype:xml",
      zip: "doctype:zip",
      png: "doctype:image",
      jpg: "doctype:image",
      jpeg: "doctype:image",
      gif: "doctype:image",
      mp4: "doctype:video",
      mp3: "doctype:audio"
    };

    const fileType = this.file.fileType ? this.file.fileType.toLowerCase() : "";
    return fileTypeIconMap[fileType] || "doctype:unknown";
  }

  get formattedCreatedDate() {
    return this.file.createdDate
      ? new Date(this.file.createdDate).toLocaleDateString()
      : "";
  }

  get cardClass() {
    const selectedClass = this.isSelected ? "selected" : "";
    const usageLevelClass = this.file.usageLevel || "";
    return `slds-card file-card ${selectedClass} ${usageLevelClass}`;
  }

  get usageLevelBadge() {
    const usageMap = {
      orphaned: { label: "🚨 Orphaned", variant: "error" },
      low_usage: { label: "⚠️ Low Usage", variant: "warning" },
      lightly_connected: { label: "🔗 Lightly Connected", variant: "info" },
      heavy_usage: { label: "✅ Heavy Usage", variant: "success" }
    };
    return (
      usageMap[this.file.usageLevel] || { label: "Unknown", variant: "inverse" }
    );
  }
}
