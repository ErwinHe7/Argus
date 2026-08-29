export class RepositoryNotFoundError extends Error {
  constructor() {
    super("resource_not_found");
    this.name = "RepositoryNotFoundError";
  }
}

export class RepositoryRevisionConflictError extends Error {
  constructor() {
    super("revision_conflict");
    this.name = "RepositoryRevisionConflictError";
  }
}

export class RepositoryStepUpRequiredError extends Error {
  constructor() {
    super("step_up_required");
    this.name = "RepositoryStepUpRequiredError";
  }
}
