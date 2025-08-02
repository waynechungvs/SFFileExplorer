import { LightningElement, api, track } from "lwc";

export default class FileFilterSidebar extends LightningElement {
  @api fileTypes = [];
  @api fileOwners = [];

  @track filters = {
    fileType: "",
    ownerId: "",
    createdDateFrom: "",
    createdDateTo: "",
    minSize: null,
    maxSize: null,
    usageLevel: "",
    inactiveOwners: false
  };

  searchTerm = "";
  searchTimeout;

  handleSearchChange(event) {
    const value = event.target.value;
    this.searchTerm = value;

    // Debounce search - dispatch immediately for now
    // TODO: Implement proper debouncing with LWC patterns
    this.dispatchEvent(
      new CustomEvent("search", {
        detail: { searchTerm: value }
      })
    );
  }

  handleFilterChange(event) {
    const field = event.target.name;
    const value = event.target.value;

    console.log("Filter change:", { field, value }); // Debug log

    if (field === "inactiveOwners") {
      this.filters[field] = event.target.checked;
    } else if (field === "minSize" || field === "maxSize") {
      this.filters[field] = value ? parseInt(value, 10) : null; // Keep as KB - Apex will convert to bytes
    } else {
      this.filters[field] = value;
    }

    console.log("Updated filters:", this.filters); // Debug log
    this.applyFilters();
  }

  handleClearFilters() {
    this.filters = {
      fileType: "",
      ownerId: "",
      createdDateFrom: "",
      createdDateTo: "",
      minSize: null,
      maxSize: null,
      usageLevel: "",
      inactiveOwners: false
    };
    this.searchTerm = "";

    this.template
      .querySelectorAll("lightning-input, lightning-combobox")
      .forEach((element) => {
        if (element.type === "checkbox") {
          element.checked = false;
        } else {
          element.value = "";
        }
      });

    this.dispatchEvent(
      new CustomEvent("search", {
        detail: { searchTerm: "" }
      })
    );
    this.applyFilters();
  }

  applyFilters() {
    // Remove null/empty values from filters
    const activeFilters = {};
    Object.keys(this.filters).forEach((key) => {
      if (
        this.filters[key] !== "" &&
        this.filters[key] !== null &&
        this.filters[key] !== false
      ) {
        activeFilters[key] = this.filters[key];
      }
    });

    console.log("Active filters being sent:", activeFilters); // Debug log

    this.dispatchEvent(
      new CustomEvent("filterchange", {
        detail: { filters: activeFilters }
      })
    );
  }

  get hasActiveFilters() {
    return (
      Object.keys(this.filters).some((key) => {
        return (
          this.filters[key] !== "" &&
          this.filters[key] !== null &&
          this.filters[key] !== false
        );
      }) || this.searchTerm !== ""
    );
  }

  get fileTypeOptions() {
    return [{ label: "All Types", value: "" }, ...this.fileTypes];
  }

  get ownerOptions() {
    return [{ label: "All Owners", value: "" }, ...this.fileOwners];
  }

  get usageLevelOptions() {
    return [
      { label: "All Files", value: "" },
      { label: "🚨 Truly Orphaned (0 links)", value: "orphaned" },
      { label: "⚠️ Low Usage (1 link)", value: "low_usage" },
      { label: "🔗 Lightly Connected (2 links)", value: "lightly_connected" },
      { label: "✅ Heavy Usage (3+ links)", value: "heavy_usage" }
    ];
  }
}
