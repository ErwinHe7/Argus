import { spawnSync } from "node:child_process";
import process from "node:process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  BETA_WORKER_NAME,
  defaultSecretStorePath,
  isDirectExecution,
  readSecretStore,
  reportCliError,
  workerSecretPayload,
} from "./beta-secret-tools.ts";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

interface DeployOptions {
  config: string;
  confirmed: boolean;
  help: boolean;
  secrets: string;
  wrangler: string;
}

function optionValue(args: readonly string[], index: number, name: string): string {
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

export function parseDeployOptions(args: readonly string[]): DeployOptions {
  const options: DeployOptions = {
    config: resolve(apiRoot, "wrangler.beta.jsonc"),
    confirmed: false,
    help: false,
    secrets: defaultSecretStorePath(),
    wrangler: resolve(apiRoot, "node_modules/wrangler/bin/wrangler.js"),
  };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    switch (argument) {
      case "--secrets":
        options.secrets = optionValue(args, index, argument);
        index += 1;
        break;
      case "--config":
        options.config = resolve(optionValue(args, index, argument));
        index += 1;
        break;
      case "--wrangler":
        options.wrangler = resolve(optionValue(args, index, argument));
        index += 1;
        break;
      case "--yes":
        options.confirmed = true;
        break;
      case "--help":
      case "-h":
        options.help = true;
        break;
      default:
        throw new Error(`unknown argument: ${argument}`);
    }
  }
  return options;
}

function printHelp(): void {
  console.log(`Bulk-upload the allowlisted beta Worker secrets.

Usage:
  npm run beta:secrets:deploy -- --yes [options]

Options:
  --secrets <path>   Protected beta secret-store JSON
  --config <path>    Beta Wrangler config
  --wrangler <path>  Wrangler JavaScript entrypoint
  --yes              Required confirmation of the remote change
  --help             Show this help

Authentication comes from Wrangler login or CLOUDFLARE_API_TOKEN.
`);
}

export function main(args = process.argv.slice(2)): void {
  const options = parseDeployOptions(args);
  if (options.help) {
    printHelp();
    return;
  }
  if (!options.confirmed) {
    throw new Error(
      `refusing to modify ${BETA_WORKER_NAME} without explicit --yes confirmation`,
    );
  }

  const store = readSecretStore(options.secrets);
  const payload = workerSecretPayload(store);
  console.log(
    `Uploading ${Object.keys(payload).length} allowlisted secrets to ${BETA_WORKER_NAME}...`,
  );
  const result = spawnSync(
    process.execPath,
    [
      options.wrangler,
      "secret",
      "bulk",
      "--config",
      options.config,
      "--name",
      BETA_WORKER_NAME,
    ],
    {
      cwd: apiRoot,
      input: `${JSON.stringify(payload)}\n`,
      stdio: ["pipe", "inherit", "inherit"],
    },
  );
  if (result.error !== undefined) throw result.error;
  if (result.status !== 0) {
    throw new Error(`Wrangler secret upload failed with status ${result.status}`);
  }
  console.log(`Uploaded beta Worker secrets to ${BETA_WORKER_NAME}.`);
}

if (isDirectExecution(import.meta.url)) {
  try {
    main();
  } catch (error) {
    reportCliError(error);
  }
}
