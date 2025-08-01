import { LightningElement, api } from "lwc";

export default class FilePreviewModal extends LightningElement {
  @api fileId;

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  get hasFileId() {
    return this.fileId != null;
  }

  get previewUrl() {
    if (this.fileId) {
      // Using the standard Salesforce file preview URL
      return `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.fileId}&operationContext=CHATTER&contentId=${this.fileId}`;
    }
    return "";
  }
}
