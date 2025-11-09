import emojiRegex from "emoji-regex";
import { wrapAsync } from "lib-result";

// Function to print to stderr in red
function printRed(message: string): never {
  console.error(`\x1b[31m${message}\x1b[0m`);
  Deno.exit(1);
}

async function processFile(path: string) {
  const regex = emojiRegex();

  const statResult = await wrapAsync(() => Deno.stat(path));
  if (statResult.isOk() && statResult.ok.isFile) {
    const text = await wrapAsync(() => Deno.readTextFile(path));
    if (text.isError()) {
      printRed(`An error occured while reading file ${path}: ${text.error}`);
    }
    const cleaned = text.ok.replaceAll(regex, "");

    if (cleaned !== text.ok) {
      const writeResult = await wrapAsync(() =>
        Deno.writeTextFile(path, cleaned, { create: false })
      );
      if (writeResult.isError()) {
        printRed(
          `An error occured while writing to file ${path}: ${writeResult.error}`
        );
      } else console.log(`Processed file '${path}' successfully!`);
    } else console.log("Nothing to do!");
  } else console.warn(`${path} is not a file`);
}

function main(argv: string[], argc: number) {
  if (argc === 0) printRed("Usage: emoji-strip <file1> [file2...]");
  argv.forEach(async path => await processFile(path));
}

if (import.meta.main) {
  main(Deno.args, Deno.args.length);
}
