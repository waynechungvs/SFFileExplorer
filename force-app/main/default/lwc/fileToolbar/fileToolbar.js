import { LightningElement, api } from "lwc";

export default class FileToolbar extends LightningElement {
  @api selectedCount = 0;
  @api totalCount = 0;
  @api viewMode = "card";
  @api sortOptions = [];
  
  allSelected = false;

  sortBy = "CreatedDate";
  sortDirection = "DESC";

  // Update allSelected state when selectedCount changes
  renderedCallback() {
    const wasAllSelected = this.allSelected;
    this.allSelected = this.selectedCount > 0 && this.selectedCount === this.totalCount;
    
    // Only re-render if state actually changed to prevent infinite loops
    if (wasAllSelected !== this.allSelected && this.template.querySelector) {
      // State changed, component will re-render automatically
    }
  }

  get viewModeOptions() {
    return [
      {
        label: "Card View",
        value: "card",
        iconName: "utility:kanban"
      },
      {
        label: "List View",
        value: "list",
        iconName: "utility:list"
      }
    ];
  }


  handleBulkDelete() {
    if (this.selectedCount > 0) {
      this.dispatchEvent(
        new CustomEvent("bulkaction", {
          detail: { action: "delete" }
        })
      );
    }
  }

  handleBulkDownload() {
    if (this.selectedCount > 0) {
      this.dispatchEvent(
        new CustomEvent("bulkaction", {
          detail: { action: "download" }
        })
      );
    }
  }

  handleBulkShare() {
    if (this.selectedCount > 0) {
      this.dispatchEvent(
        new CustomEvent("bulkaction", {
          detail: { action: "bulkshare" }
        })
      );
    }
  }

  handleBulkChangeOwner() {
    if (this.selectedCount > 0) {
      this.dispatchEvent(
        new CustomEvent("bulkaction", {
          detail: { action: "bulkchangeowner" }
        })
      );
    }
  }

  handleSelectAllToggle() {
    this.allSelected = !this.allSelected;
    this.dispatchEvent(
      new CustomEvent("selectall", {
        detail: { isSelected: this.allSelected }
      })
    );
  }

  handleViewModeChange(event) {
    const newViewMode = event.currentTarget.dataset.value;
    if (newViewMode !== this.viewMode) {
      this.dispatchEvent(
        new CustomEvent("viewmodechange", {
          detail: { viewMode: newViewMode }
        })
      );
    }
  }

  handleSortChange(event) {
    this.sortBy = event.detail.value;
    this.emitSortEvent();
  }

  handleSortDirectionToggle() {
    this.sortDirection = this.sortDirection === "ASC" ? "DESC" : "ASC";
    this.emitSortEvent();
  }

  emitSortEvent() {
    this.dispatchEvent(
      new CustomEvent("sort", {
        detail: {
          sortBy: this.sortBy,
          sortDirection: this.sortDirection
        }
      })
    );
  }

  get isCardView() {
    return this.viewMode === "card";
  }

  get isListView() {
    return this.viewMode === "list";
  }

  get hasSelection() {
    return this.selectedCount > 0;
  }

  get hasNoSelection() {
    return this.selectedCount === 0;
  }

  get selectionText() {
    if (this.selectedCount === 0) {
      return `${this.totalCount} files`;
    }
    return `${this.selectedCount} of ${this.totalCount} selected`;
  }

  get sortIconName() {
    return this.sortDirection === "ASC"
      ? "utility:arrowup"
      : "utility:arrowdown";
  }

  get deleteButtonVariant() {
    return this.hasSelection ? "destructive" : "neutral";
  }

  get downloadButtonVariant() {
    return this.hasSelection ? "brand" : "neutral";
  }

  get selectAllButtonLabel() {
    return this.allSelected ? "Deselect All" : "Select All";
  }

  get selectAllIconName() {
    return this.allSelected ? "utility:clear" : "utility:check";
  }
}
