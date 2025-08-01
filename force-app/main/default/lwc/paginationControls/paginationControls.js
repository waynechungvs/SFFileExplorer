import { LightningElement, api } from "lwc";

export default class PaginationControls extends LightningElement {
  @api pageNumber = 1;
  @api pageSize = 25;
  @api totalCount = 0;
  @api pageSizeOptions = [];

  handlePrevious() {
    if (this.pageNumber > 1) {
      this.dispatchEvent(
        new CustomEvent("pagechange", {
          detail: { pageNumber: this.pageNumber - 1 }
        })
      );
    }
  }

  handleNext() {
    if (this.pageNumber < this.totalPages) {
      this.dispatchEvent(
        new CustomEvent("pagechange", {
          detail: { pageNumber: this.pageNumber + 1 }
        })
      );
    }
  }

  handleFirst() {
    if (this.pageNumber !== 1) {
      this.dispatchEvent(
        new CustomEvent("pagechange", {
          detail: { pageNumber: 1 }
        })
      );
    }
  }

  handleLast() {
    if (this.pageNumber !== this.totalPages) {
      this.dispatchEvent(
        new CustomEvent("pagechange", {
          detail: { pageNumber: this.totalPages }
        })
      );
    }
  }

  handlePageSizeChange(event) {
    const newPageSize = parseInt(event.detail.value, 10);
    this.dispatchEvent(
      new CustomEvent("pagesizechange", {
        detail: { pageSize: newPageSize }
      })
    );
  }

  handlePageNumberChange(event) {
    const value = parseInt(event.target.value, 10);
    if (value >= 1 && value <= this.totalPages) {
      this.dispatchEvent(
        new CustomEvent("pagechange", {
          detail: { pageNumber: value }
        })
      );
    }
  }

  get totalPages() {
    return Math.ceil(this.totalCount / this.pageSize) || 1;
  }

  get isFirstPage() {
    return this.pageNumber === 1;
  }

  get isLastPage() {
    return this.pageNumber >= this.totalPages;
  }

  get startRecord() {
    return (this.pageNumber - 1) * this.pageSize + 1;
  }

  get endRecord() {
    const end = this.pageNumber * this.pageSize;
    return end > this.totalCount ? this.totalCount : end;
  }

  get hasRecords() {
    return this.totalCount > 0;
  }

  get pageInfo() {
    if (!this.hasRecords) {
      return "No records to display";
    }
    return `${this.startRecord}-${this.endRecord} of ${this.totalCount}`;
  }

  get pageSizeOptionsFormatted() {
    return this.pageSizeOptions.map((option) => ({
      label: `${option.label} per page`,
      value: option.value
    }));
  }
}
