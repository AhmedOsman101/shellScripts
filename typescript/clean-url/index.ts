import { basename } from "node:path";
import process from "node:process";
import { createInterface } from "node:readline";
import { $ } from "bun";

type CleanedUrl = { cleanedUrl: string; furtherCleanedUrl?: string };

async function input(prompt: string): Promise<string> {
  // Create readline interface
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  // Get user input using a promise
  const plaintext = await new Promise<string>(resolve => {
    rl.question(prompt, answer => {
      resolve(answer);
    });
  });

  // Close the readline interface
  rl.close();

  return plaintext;
}

// Function to print to stderr in red
function logError(message: string): never {
  process.stderr.write("\x1b[31m[ERROR]\x1b[0m");
  process.stderr.write(` ${message}\n`);
  process.exit(1);
}

// Function to clean the URL
function cleanUrl(url: string): CleanedUrl {
  try {
    // Check for Google search URL (e.g., http://google.com/search?q=query)
    if (/^http[^?]*\/search\?/.test(url)) {
      const parts = url.split("?");
      if (parts.length !== 2) {
        throw new Error("Invalid Google search URL format");
      }
      let [part0, part1] = parts;

      part1 = `?${parts[1]}`;
      let tbm = ""; // e.g. for image search
      if (/&tbm=/.test(url)) {
        tbm = part1.replace(/.*?[&?]tbm=/i, "");
        tbm = `&tbm=${tbm.replace(/&.*/, "")}`;
      }
      part1 = part1.replace(/.*?[&?]q=/i, "");
      part1 = part1.replace(/&.*/, "");
      return { cleanedUrl: `${part0}?q=${part1}${tbm}` };
    }
    // Check for Google redirect URL (e.g., https://www.google.com/url?url=https%3A%2F%2Fexample.com)
    if (/^https?:\/\/.*[&?]url=/.test(url)) {
      const cleaned = decodeURIComponent(
        url.replace(/.*?[&?]url=/i, "").replace(/&.*/, "")
      );
      const parts = cleaned.split(/[?#]/);
      return {
        cleanedUrl: cleaned,
        furtherCleanedUrl: parts.length > 1 ? parts[0] : undefined,
      };
    }

    // Check for encoded URL pattern (e.g., https://www.google.com/?q=https%3A%2F%2Fexample.com)
    if (/^https?:\/\/.*\?.*=https?%3A%2F%2F/.test(url)) {
      const cleaned = decodeURIComponent(
        url.match(/=https?%3A%2F%2F[A-Za-z0-9-_.!~*'()%]*/)?.[0]?.slice(1) || ""
      );
      const parts = cleaned.split(/[?#]/);
      return {
        cleanedUrl: cleaned,
        furtherCleanedUrl: parts.length > 1 ? parts[0] : undefined,
      };
    }

    // Default case: strip query parameters and fragments
    const parts = url.split(/[?#]/);
    if (parts.length < 2) {
      return { cleanedUrl: url };
    }
    return { cleanedUrl: parts[0] as string };
  } catch (error) {
    logError(
      `Cleaning URL: ${error instanceof Error ? error.message : "Unknown error"}`
    );
  }
}

function validateUrl(url: unknown): void {
  try {
    if (typeof url === "string") {
      new URL(url);
      return;
    }
    logError("URL must be string");
  } catch {
    logError("Invalid URL");
  }
}

function proccessUrl(url: string) {
  // Validate URL format
  const disallowedCharPattern = /[<>"]/;
  const httpFtpPattern = /^(http:\/\/|https:\/\/|ftp:\/\/).*$/;

  const { cleanedUrl, furtherCleanedUrl } = cleanUrl(url);
  if (
    httpFtpPattern.test(cleanedUrl) &&
    !disallowedCharPattern.test(cleanedUrl)
  ) {
    process.stdout.write(`${furtherCleanedUrl ?? cleanedUrl}\n`);
  } else {
    logError("Unable to extract the link.");
  }
}

async function main() {
  // Get command-line arguments
  const url = process.argv.at(2) || (await input("Enter a URL to clean: "));
  if (!url.trim()) {
    logError(`No URL provided. Usage: ${basename(process.argv0)} <URL>`);
  }

  if (url.trim() === "--test") {
    await $`bash test.sh`;
    process.exit(0);
  }
  validateUrl(url);
  proccessUrl(url);
}

if (import.meta.main) main();
