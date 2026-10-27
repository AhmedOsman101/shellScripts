import { statSync } from "node:fs";
import emojiRegex from "emoji-regex";
import { wrap, wrapAsync } from "lib-result";

const encoder = new TextEncoder();

// Function to print to stderr in red
function logError(message: string): never {
  process.stderr.write("\x1b[31m[ERROR]\x1b[0m");
  process.stderr.write(` ${message}\n`);
  process.exit(1);
}

async function print(...args: string[]) {
  process.stdout.write(encoder.encode(args.join(" ")));
}

const stripEmojies = (str: string) => str.replaceAll(emojiRegex(), "");

async function processFile(path: string) {
  const text = await wrapAsync(async () => await Bun.file(path).text());
  if (text.isError()) {
    logError(`An error occured while reading file ${path}: ${text.error}`);
  }

  const cleaned = stripEmojies(text.ok);
  if (cleaned === text.ok) {
    await print(`Nothing to clean in '${path}'\n`);
    return;
  }

  const writeResult = await wrapAsync(
    async () => await Bun.write(path, cleaned, { createPath: false })
  );
  if (writeResult.isError()) {
    logError(
      `An error occured while writing to file ${path}: ${writeResult.error}`
    );
  } else await print(`Processed file '${path}' successfully!\n`);
}

async function processArg(arg: string) {
  const statResult = wrap(() => statSync(arg));

  if (statResult.isOk() && statResult.ok.isFile()) {
    await print("\n");
    await processFile(arg);
  } else {
    // Treat argument as raw text input
    await print(`${stripEmojies(arg)} `);
  }
}

async function main(argv: string[], argc: number) {
  if (argc === 0) {
    logError("Usage: emoji-strip <file1|text> [more files or text...]");
  }

  for (const arg of argv) await processArg(arg);
  await print("\n");
}

if (import.meta.main) {
  await main(process.argv.slice(2), process.argv.length - 2);
}
