import { pathToFileURL } from "node:url";

type EnvironmentResources = {
  environment: "production" | "beta";
  landing: { service: string; host: string };
  demo: { service: string; host: string };
  rateLimits: {
    source: { binding: "WAITLIST_SOURCE_RATE_LIMIT"; resource: string; namespaceId: string };
    route: { binding: "WAITLIST_ROUTE_RATE_LIMIT"; resource: string; namespaceId: string };
  };
  wafBudget: { rule: string; ceiling: string };
  denialJournal: {
    resource: string;
    maintenanceOnly: true;
    availableToLandingRuntime: false;
  };
  submissionKillSwitch: { binding: "WAITLIST_SUBMISSIONS"; initialValue: "off" };
  turnstile: {
    widget: string;
    hostname: string;
    action: "waitlist";
    siteKeyResource: string;
    secretResource: string;
  };
  neon: {
    project: string;
    ownerCredential: string;
    runtimeCredential: string;
    workerSecretBinding: "WAITLIST_NEON_URL";
  };
  telemetry: { binding: "WAITLIST_TELEMETRY"; dataset: string };
  retention: {
    cron: "17 4 * * *";
    checkpointBinding: "RETENTION_CHECKPOINT";
    checkpointNamespace: string;
    checkpointNamespaceId: string;
    purgeCapability: string;
  };
  protocol: { current: 2; previous: 1; trustedLandingOrigin: string; trustedDemoOrigin: string };
  provisioningState: "required-before-upload";
};

export const RESOURCE_MANIFEST = {
  production: {
    environment: "production",
    landing: { service: "ritual-investing-site", host: "just-build-this.app" },
    demo: { service: "ritual-investing-demo", host: "demo.just-build-this.app" },
    rateLimits: {
      source: { binding: "WAITLIST_SOURCE_RATE_LIMIT", resource: "ritual-waitlist-prod-source-v1", namespaceId: "3101" },
      route: { binding: "WAITLIST_ROUTE_RATE_LIMIT", resource: "ritual-waitlist-prod-route-v1", namespaceId: "3102" },
    },
    wafBudget: { rule: "ritual-waitlist-prod-budget-v1", ceiling: "ritual-waitlist-prod-budget-1m" },
    denialJournal: {
      resource: "ritual-waitlist-prod-denial-journal-v1",
      maintenanceOnly: true,
      availableToLandingRuntime: false,
    },
    submissionKillSwitch: { binding: "WAITLIST_SUBMISSIONS", initialValue: "off" },
    turnstile: {
      widget: "ritual-waitlist-prod-widget-v1",
      hostname: "just-build-this.app",
      action: "waitlist",
      siteKeyResource: "ritual-waitlist-prod-site-key-v1",
      secretResource: "ritual-waitlist-prod-turnstile-secret-v1",
    },
    neon: {
      project: "ritual-waitlist-prod-neon-v1",
      ownerCredential: "ritual-waitlist-prod-owner-url-v1",
      runtimeCredential: "ritual-waitlist-prod-runtime-url-v1",
      workerSecretBinding: "WAITLIST_NEON_URL",
    },
    telemetry: { binding: "WAITLIST_TELEMETRY", dataset: "ritual_waitlist_prod_events_v1" },
    retention: {
      cron: "17 4 * * *",
      checkpointBinding: "RETENTION_CHECKPOINT",
      checkpointNamespace: "ritual-waitlist-prod-retention-checkpoint-v1",
      checkpointNamespaceId: "00000000000000000000000000000001",
      purgeCapability: "ritual-waitlist-prod-purge-expired-v1",
    },
    protocol: {
      current: 2,
      previous: 1,
      trustedLandingOrigin: "https://just-build-this.app",
      trustedDemoOrigin: "https://demo.just-build-this.app",
    },
    provisioningState: "required-before-upload",
  },
  beta: {
    environment: "beta",
    landing: { service: "ritual-investing-site-beta", host: "beta.just-build-this.app" },
    demo: { service: "ritual-investing-demo-beta", host: "demo-beta.just-build-this.app" },
    rateLimits: {
      source: { binding: "WAITLIST_SOURCE_RATE_LIMIT", resource: "ritual-waitlist-beta-source-v1", namespaceId: "4101" },
      route: { binding: "WAITLIST_ROUTE_RATE_LIMIT", resource: "ritual-waitlist-beta-route-v1", namespaceId: "4102" },
    },
    wafBudget: { rule: "ritual-waitlist-beta-budget-v1", ceiling: "ritual-waitlist-beta-budget-1m" },
    denialJournal: {
      resource: "ritual-waitlist-beta-denial-journal-v1",
      maintenanceOnly: true,
      availableToLandingRuntime: false,
    },
    submissionKillSwitch: { binding: "WAITLIST_SUBMISSIONS", initialValue: "off" },
    turnstile: {
      widget: "ritual-waitlist-beta-widget-v1",
      hostname: "beta.just-build-this.app",
      action: "waitlist",
      siteKeyResource: "ritual-waitlist-beta-site-key-v1",
      secretResource: "ritual-waitlist-beta-turnstile-secret-v1",
    },
    neon: {
      project: "ritual-waitlist-beta-neon-v1",
      ownerCredential: "ritual-waitlist-beta-owner-url-v1",
      runtimeCredential: "ritual-waitlist-beta-runtime-url-v1",
      workerSecretBinding: "WAITLIST_NEON_URL",
    },
    telemetry: { binding: "WAITLIST_TELEMETRY", dataset: "ritual_waitlist_beta_events_v1" },
    retention: {
      cron: "17 4 * * *",
      checkpointBinding: "RETENTION_CHECKPOINT",
      checkpointNamespace: "ritual-waitlist-beta-retention-checkpoint-v1",
      checkpointNamespaceId: "00000000000000000000000000000002",
      purgeCapability: "ritual-waitlist-beta-purge-expired-v1",
    },
    protocol: {
      current: 2,
      previous: 1,
      trustedLandingOrigin: "https://beta.just-build-this.app",
      trustedDemoOrigin: "https://demo-beta.just-build-this.app",
    },
    provisioningState: "required-before-upload",
  },
} as const satisfies Record<"production" | "beta", EnvironmentResources>;

function physicalIdentifiers(resources: EnvironmentResources): string[] {
  return [
    resources.landing.service,
    resources.landing.host,
    resources.demo.service,
    resources.demo.host,
    resources.rateLimits.source.resource,
    resources.rateLimits.source.namespaceId,
    resources.rateLimits.route.resource,
    resources.rateLimits.route.namespaceId,
    resources.wafBudget.rule,
    resources.wafBudget.ceiling,
    resources.denialJournal.resource,
    resources.turnstile.widget,
    resources.turnstile.siteKeyResource,
    resources.turnstile.secretResource,
    resources.neon.project,
    resources.neon.ownerCredential,
    resources.neon.runtimeCredential,
    resources.telemetry.dataset,
    resources.retention.checkpointNamespace,
    resources.retention.checkpointNamespaceId,
    resources.retention.purgeCapability,
    resources.protocol.trustedLandingOrigin,
    resources.protocol.trustedDemoOrigin,
  ];
}

export function validateResourceManifest(
  manifest: typeof RESOURCE_MANIFEST,
): string[] {
  const errors: string[] = [];
  const production = manifest.production;
  const beta = manifest.beta;
  const overlap = physicalIdentifiers(production).filter((identifier) =>
    physicalIdentifiers(beta).includes(identifier),
  );
  if (overlap.length > 0) errors.push(`Production/beta resource overlap: ${overlap.join(", ")}`);

  for (const resources of [production, beta]) {
    if (new Set(physicalIdentifiers(resources)).size !== physicalIdentifiers(resources).length) {
      errors.push(`${resources.environment} reuses a physical resource identifier.`);
    }
    if (!resources.denialJournal.maintenanceOnly || resources.denialJournal.availableToLandingRuntime) {
      errors.push(`${resources.environment} denial journal must remain maintenance-only.`);
    }
    if (resources.submissionKillSwitch.initialValue !== "off") {
      errors.push(`${resources.environment} submissions must begin fail-closed.`);
    }
    if (resources.turnstile.hostname !== resources.landing.host || resources.turnstile.action !== "waitlist") {
      errors.push(`${resources.environment} Turnstile trust does not match its landing host/action.`);
    }
    if (resources.protocol.trustedLandingOrigin !== `https://${resources.landing.host}` ||
        resources.protocol.trustedDemoOrigin !== `https://${resources.demo.host}`) {
      errors.push(`${resources.environment} protocol peers do not match their exact hosts.`);
    }
    if (resources.provisioningState !== "required-before-upload") {
      errors.push(`${resources.environment} must be provisioned and verified before upload.`);
    }
  }

  return errors;
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const errors = validateResourceManifest(RESOURCE_MANIFEST);
  if (errors.length > 0) {
    process.stderr.write(`${errors.join("\n")}\n`);
    process.exitCode = 1;
  } else {
    process.stdout.write("Resource manifest is pairwise isolated and maintenance boundaries are valid.\n");
  }
}
