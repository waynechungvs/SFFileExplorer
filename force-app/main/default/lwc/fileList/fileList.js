import { LightningElement, api } from "lwc";

export default class FileList extends LightningElement {
  @api files = [];
  @api viewMode = "card";
  @api selectedFiles = [];

  handleFileSelect(event) {
    let fileId, isSelected;
    
    // Handle different event sources
    if (event.detail && event.detail.fileId !== undefined) {
      // From fileCard component (card view)
      fileId = event.detail.fileId;
      isSelected = event.detail.isSelected;
    } else {
      // From list view checkbox (dataset attributes)
      fileId = event.currentTarget.dataset.fileId;
      isSelected = event.target.checked;
    }

    this.dispatchEvent(
      new CustomEvent("fileselect", {
        detail: { fileId, isSelected }
      })
    );
  }

  handleFileClick(event) {
    const fileId = event.currentTarget.dataset.fileId;

    this.dispatchEvent(
      new CustomEvent("filepreview", {
        detail: { fileId }
      })
    );
  }

  handleFileShare(event) {
    const fileId = event.detail.fileId;
    
    this.dispatchEvent(
      new CustomEvent("fileshare", {
        detail: { fileId }
      })
    );
  }

  handleFileShareFromMenu(event) {
    const fileId = event.currentTarget.dataset.fileId;
    
    this.dispatchEvent(
      new CustomEvent("fileshare", {
        detail: { fileId }
      })
    );
  }

  handleSelectAllToggle(event) {
    const isSelected = event.target.checked;
    
    this.dispatchEvent(
      new CustomEvent("selectall", {
        detail: { isSelected }
      })
    );
  }

  handleLinksClick(event) {
    let fileId, fileName;
    
    // Handle different event sources
    if (event.detail) {
      // From fileCard component (card view)
      fileId = event.detail.fileId;
      fileName = event.detail.fileName;
    } else {
      // From list view element (dataset attributes)
      fileId = event.currentTarget.dataset.fileId;
      fileName = event.currentTarget.dataset.fileName;
    }
    
    this.dispatchEvent(
      new CustomEvent("viewconnections", {
        detail: { fileId, fileName }
      })
    );
  }

  handleChangeOwner(event) {
    const { fileId, fileName, currentOwnerName } = event.detail;
    
    this.dispatchEvent(
      new CustomEvent("changeowner", {
        detail: { fileId, fileName, currentOwnerName }
      })
    );
  }

  handleChangeOwnerFromMenu(event) {
    const fileId = event.currentTarget.dataset.fileId;
    const fileName = event.currentTarget.dataset.fileName;
    const currentOwnerName = event.currentTarget.dataset.currentOwner;
    
    this.dispatchEvent(
      new CustomEvent("changeowner", {
        detail: { fileId, fileName, currentOwnerName }
      })
    );
  }

  isFileSelected(fileId) {
    return this.selectedFiles.includes(fileId);
  }

  get isCardView() {
    return this.viewMode === "card";
  }

  get isListView() {
    return this.viewMode === "list";
  }

  get filesWithSelection() {
    return this.files.map((file) => ({
      ...file,
      isSelected: this.isFileSelected(file.contentDocumentId)
    }));
  }
}
