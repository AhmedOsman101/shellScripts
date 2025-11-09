#!/usr/bin/env -S deno run --allow-read --allow-write

import emojiRegex from "emoji-regex";
import { wrapAsync } from "lib-result";

const encoder = new TextEncoder();

// Function to print to stderr in red
function printRed(message: string): never {
  console.error(`\x1b[31m${message}\x1b[0m`);
  Deno.exit(1);
}

async function print(...args: string[]) {
  await Deno.stdout.write(encoder.encode(args.join(" ")));
}

const stripEmojies = (str: string) => str.replaceAll(emojiRegex(), "");

async function processFile(path: string) {
  const text = await wrapAsync(() => Deno.readTextFile(path));
  if (text.isError()) {
    printRed(`An error occured while reading file ${path}: ${text.error}`);
  }

  const cleaned = stripEmojies(text.ok);
  if (cleaned === text.ok) {
    await print(`Nothing to clean in '${path}'\n`);
    return;
  }

  const writeResult = await wrapAsync(() =>
    Deno.writeTextFile(path, cleaned, { create: false })
  );
  if (writeResult.isError()) {
    printRed(
      `An error occured while writing to file ${path}: ${writeResult.error}`
    );
  } else await print(`Processed file '${path}' successfully!\n`);
}

async function processArg(arg: string) {
  const statResult = await wrapAsync(() => Deno.stat(arg));

  if (statResult.isOk() && statResult.ok.isFile) {
    await print("\n");
    await processFile(arg);
  } else {
    // Treat argument as raw text input
    await print(`${stripEmojies(arg)} `);
  }
}

async function main(argv: string[], argc: number) {
  if (argc === 0) {
    printRed("Usage: emoji-strip <file1|text> [more files or text...]");
  }

  for (const arg of argv) await processArg(arg);
  await print("\n");
}

if (import.meta.main) {
  await main(Deno.args, Deno.args.length);
}
