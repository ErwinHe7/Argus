import { readFileSync } from "node:fs";
import process from "node:process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  defaultSecretStorePath,
  defaultSqlOutputPath,
  isDirectExecution,
  readSecretStore,
  reportCliError,
  requireKeys,
  roleDefinitions,
  writePrivateFile,
} from "./beta-secret-tools.ts";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const defaultTemplatePath = resolve(
  apiRoot,
  "ops/provision-runtime-roles.sql.example",
);

interface RenderOptions {
  force: boolean;
  help: boolean;
  output: string;
  secrets: string;
  template: string;
}

function optionValue(args: readonly string[], index: number, name: string): string {
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

export function parseRenderOptions(args: readonly string[]): RenderOptions {
  const options: RenderOptions = {
    force: false,
    help: false,
    output: defaultSqlOutputPath(),
    secrets: defaultSecretStorePath(),
    template: defaultTemplatePath,
  };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    switch (argument) {
      case "--secrets":
        options.secrets = optionValue(args, index, argument);
        index += 1;
        break;
      case "--template":
        options.template = optionValue(args, index, argument);
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

function sqlLiteral(value: string): string {
  return value.replaceAll("'", "''");
}

export function renderRoleSql(template: string, store: Record<string, string>): string {
  const passwordKeys = roleDefinitions.map(
    (definition) => definition.passwordKey,
  );
  requireKeys(store, passwordKeys);
  let rendered = template;
  for (const definition of roleDefinitions) {
    const placeholder = `<${definition.passwordKey}>`;
    if (!rendered.includes(placeholder)) {
      throw new Error(`SQL template is missing ${placeholder}`);
    }
    rendered = rendered.replaceAll(
      placeholder,
      sqlLiteral(store[definition.passwordKey]!),
    );
  }
  const unresolved = rendered.match(/<[A-Z_]+_PASSWORD>/g);
  if (unresolved !== null) {
    throw new Error(`SQL template still contains ${unresolved.join(", ")}`);
  }
  return rendered.replace(/\n*$/, "\n");
}

function printHelp(): void {
  console.log(`Render the private Neon role-provisioning SQL file.

Usage:
  npm run beta:secrets:sql -- [options]

Options:
  --secrets <path>   Protected beta secret-store JSON
  --template <path>  SQL template path
  --output <path>    Protected populated SQL output path
  --force            Replace an existing output file
  --help             Show this help
`);
}

export function main(args = process.argv.slice(2)): void {
  const options = parseRenderOptions(args);
  if (options.help) {
    printHelp();
    return;
  }
  const store = readSecretStore(options.secrets);
  const template = readFileSync(options.template, "utf8");
  const sql = renderRoleSql(template, store);
  writePrivateFile(options.output, sql, options.force);
  console.log(`Created protected Neon SQL file at ${options.output}`);
}

if (isDirectExecution(import.meta.url)) {
  try {
    main();
  } catch (error) {
    reportCliError(error);
  }
}
