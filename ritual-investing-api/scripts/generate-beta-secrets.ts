import process from "node:process";

import {
  defaultSecretStorePath,
  generateBetaSecretStore,
  isDirectExecution,
  reportCliError,
  writePrivateFile,
} from "./beta-secret-tools.ts";

interface GenerateOptions {
  database: string;
  force: boolean;
  help: boolean;
  neonHost?: string;
  output: string;
}

function optionValue(args: readonly string[], index: number, name: string): string {
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

export function parseGenerateOptions(args: readonly string[]): GenerateOptions {
  const options: GenerateOptions = {
    database: "neondb",
    force: false,
    help: false,
    output: defaultSecretStorePath(),
  };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    switch (argument) {
      case "--neon-host":
        options.neonHost = optionValue(args, index, argument);
        index += 1;
        break;
      case "--database":
        options.database = optionValue(args, index, argument);
        index += 1;
        break;
      case "--output":
        options.output = optionValue(args, index, argument);
        index += 1;
        break;
      case "--force":
        options.force = true;
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
  console.log(`Generate beta role passwords and Worker secrets.

Usage:
  npm run beta:secrets:generate -- --neon-host <pooled-host> [options]

Options:
  --neon-host <host>  Required pooled Neon hostname, with optional port
  --database <name>   Neon database name (default: neondb)
  --output <path>     Protected JSON output path
  --force             Replace an existing output file
  --help              Show this help
`);
}

export function main(args = process.argv.slice(2)): void {
  const options = parseGenerateOptions(args);
  if (options.help) {
    printHelp();
    return;
  }
  if (options.neonHost === undefined) {
    throw new Error("--neon-host is required; use the beta branch pooled hostname");
  }
  const store = generateBetaSecretStore(options.neonHost, options.database);
  writePrivateFile(
    options.output,
    `${JSON.stringify(store, null, 2)}\n`,
    options.force,
  );
  console.log(`Created protected beta secret store at ${options.output}`);
}

if (isDirectExecution(import.meta.url)) {
  try {
    main();
  } catch (error) {
    reportCliError(error);
  }
}
