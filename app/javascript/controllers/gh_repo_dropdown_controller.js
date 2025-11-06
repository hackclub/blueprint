import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "input",
    "datalist",
    "error",
    "refreshIcon",
    "checkIcon",
    "detailsDiv",
    "titleInput",
    "descriptionInput",
    "nextButton",
    "warning",
  ];
  static values = {
    skipChecks: Boolean,
    existingLinks: Array,
  };

  connect() {
    if (!this.shouldSkipChecks()) {
      this.fetchRepositories();
    }
    this.repositories = [];
    this.updateNextButton();
  }

  shouldSkipChecks() {
    return this.skipChecksValue;
  }

  async fetchRepositories() {
    if (this.shouldSkipChecks()) {
      return;
    }

    this.clearError();
    this.setLoading(true);

    try {
      const response = await fetch("/projects/list_repos");
      const data = await response.json();

      if (data.ok) {
        this.repositories = data.repositories;
        this.populateDatalist(data.repositories);
        this.showSuccess();
      } else {
        this.showError(data.error || "Failed to fetch repositories");
      }
    } catch (error) {
      this.showError("Failed to fetch repositories");
    } finally {
      this.setLoading(false);
    }
  }

  populateDatalist(repositories) {
    this.datalistTarget.innerHTML = "";
    const existingLinks = this.existingLinksValue || [];
    console.log("Populating datalist. Existing links:", existingLinks);

    repositories.forEach((repo) => {
      const option = document.createElement("option");
      const repoUrl = `https://github.com/${repo.full_name}`;
      option.value = repoUrl;

      const isUsed = existingLinks.some(
        (link) => link.includes(repo.full_name) || repoUrl === link
      );

      console.log(
        `Repo ${repo.full_name}: isUsed=${isUsed}, repoUrl=${repoUrl}`
      );

      option.textContent = `${repo.description || "No description"}${
        isUsed ? " (Used by another project)" : ""
      }`;

      this.datalistTarget.appendChild(option);
    });
  }

  async onRepoInputChange() {
    const repoLink = this.inputTarget.value.trim();

    if (!this.validateRepoLink(repoLink)) {
      this.hideDetails();
      this.updateNextButton();
      return;
    }

    // Check if it's a GitHub link
    const isGithubLink =
      repoLink.match(/github\.com/i) || !repoLink.match(/^https?:\/\//);

    if (!isGithubLink) {
      // Non-GitHub link - show warning
      this.showWarning(
        "Other Git hosts are allowed, but not recommended. Please make sure it's publicly accessible."
      );
    } else {
      this.clearWarning();

      // Check if repo is in the fetched list
      const repoPath = this.extractRepoInfo(repoLink);
      const repoInList = this.repositories.some(
        (r) => r.full_name === repoPath
      );

      if (!repoInList && !this.shouldSkipChecks()) {
        // Not in list, need to check with API
        await this.checkGithubRepo(repoLink);
      }
    }

    this.showDetails();
    this.preFillDetails(repoLink);
    this.updateNextButton();
  }

  async checkGithubRepo(repoLink) {
    try {
      const repoPath = this.extractRepoInfo(repoLink);
      const response = await fetch("/projects/check_github_repo", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        },
        body: JSON.stringify({ repo: repoPath }),
      });

      const data = await response.json();

      if (!data.ok) {
        this.showError(data.error || "Failed to validate GitHub repository");
        this.hideDetails();
        return false;
      }

      this.clearError();
      return true;
    } catch (error) {
      this.showError("Failed to validate repository");
      this.hideDetails();
      return false;
    }
  }

  validateRepoLink(link) {
    if (!link) return false;

    // Check if link is already used
    const existingLinks = this.existingLinksValue || [];
    const isUsed = existingLinks.some((existing) => {
      // Normalize links for comparison
      const normalizedExisting = existing
        .toLowerCase()
        .replace(/^https?:\/\//, "")
        .replace(/^github\.com\//, "");
      const normalizedLink = link
        .toLowerCase()
        .replace(/^https?:\/\//, "")
        .replace(/^github\.com\//, "");
      return normalizedExisting === normalizedLink;
    });

    if (isUsed) {
      this.showError("This repository is already used by another project");
      return false;
    }

    // URL format
    const urlPattern = /^https?:\/\/.+/;
    // user/repo format
    const userRepoPattern = /^[\w-]+\/[\w-]+$/;

    return urlPattern.test(link) || userRepoPattern.test(link);
  }

  extractRepoInfo(link) {
    // Extract user/repo from various formats
    let repoPath = link;

    if (link.includes("github.com/")) {
      repoPath = link.split("github.com/")[1].split("/").slice(0, 2).join("/");
    }

    return repoPath;
  }

  preFillDetails(repoLink) {
    const repoPath = this.extractRepoInfo(repoLink);
    const repo = this.repositories.find((r) => r.full_name === repoPath);

    if (repo) {
      // Convert name: my-project-2000 -> My Project 2000
      const formattedName = this.formatProjectName(repo.name);
      this.titleInputTarget.value = formattedName;

      // Set description (or leave blank)
      this.descriptionInputTarget.value = repo.description || "";
    } else {
      // If not from fetched repos, try to extract from URL
      const parts = repoPath.split("/");
      const projectName = parts[parts.length - 1];
      this.titleInputTarget.value = this.formatProjectName(projectName);
      this.descriptionInputTarget.value = "";
    }

    this.updateNextButton();
  }

  formatProjectName(name) {
    return name
      .split(/[-_]/)
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(" ");
  }

  showDetails() {
    if (this.hasDetailsDivTarget) {
      this.detailsDivTarget.classList.remove("hidden");
    }
  }

  hideDetails() {
    if (this.hasDetailsDivTarget) {
      this.detailsDivTarget.classList.add("hidden");
    }
  }

  updateNextButton() {
    if (!this.hasNextButtonTarget) return;

    const hasRepoLink = this.validateRepoLink(this.inputTarget.value.trim());
    const hasTitle =
      this.hasTitleInputTarget && this.titleInputTarget.value.trim().length > 0;

    if (hasRepoLink && hasTitle) {
      this.nextButtonTarget.disabled = false;
      this.nextButtonTarget.classList.remove(
        "opacity-50",
        "cursor-not-allowed",
        "pointer-events-none"
      );
      this.nextButtonTarget.removeAttribute("disabled");
    } else {
      this.nextButtonTarget.disabled = true;
      this.nextButtonTarget.classList.add(
        "opacity-50",
        "cursor-not-allowed",
        "pointer-events-none"
      );
      this.nextButtonTarget.setAttribute("disabled", "disabled");
    }
  }

  onTitleChange() {
    this.updateNextButton();
  }

  setLoading(isLoading) {
    if (isLoading) {
      this.refreshIconTarget.classList.add("animate-spin");
    } else {
      this.refreshIconTarget.classList.remove("animate-spin");
    }
  }

  showSuccess() {
    this.refreshIconTarget.classList.add("hidden");
    this.checkIconTarget.classList.remove("hidden");

    setTimeout(() => {
      this.checkIconTarget.classList.add("hidden");
      this.refreshIconTarget.classList.remove("hidden");
    }, 1000);
  }

  showError(message) {
    this.clearWarning();
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove("hidden");
    }
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = "";
      this.errorTarget.classList.add("hidden");
    }
  }

  showWarning(message) {
    this.clearError();
    if (this.hasWarningTarget) {
      this.warningTarget.textContent = message;
      this.warningTarget.classList.remove("hidden");
    }
  }

  clearWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.textContent = "";
      this.warningTarget.classList.add("hidden");
    }
  }

  refresh() {
    this.fetchRepositories();
  }
}
