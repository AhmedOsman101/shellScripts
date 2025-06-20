import process from "node:process";
import { createInterface } from "node:readline";

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
function printRed(message: string): never {
  console.error(`\x1b[31m${message}\x1b[0m`);
  Deno.exit(1);
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
    return { cleanedUrl: parts[0] };
  } catch (error) {
    printRed(
      `Error cleaning URL: ${error instanceof Error ? error.message : "Unknown error"}`
    );
  }
}

function validateUrl(url: unknown): void {
  try {
    if (typeof url === "string") {
      new URL(url);
      return;
    }
    printRed("URL must be string");
  } catch {
    printRed("Invalid URL");
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
    console.log(furtherCleanedUrl ?? cleanedUrl);
  } else {
    printRed("Sorry, URL Clean couldn't extract the link.");
  }
}

async function main() {
  // Get command-line arguments
  const url = Deno.args.at(0) || (await input("Enter a URL to clean: "));

  if (!url.trim()) printRed("Error: No URL provided. Usage: cleanurl <URL>");
  if (url.trim() === "--test") testUrls();

  validateUrl(url);
  proccessUrl(url);
}

export function testUrls(): never {
  const urls = [
    "http://www.google.com/search?q=test+query&oq=test&aqs=chrome.0.69i59j69i60l2.1234j0j1&sourceid=chrome&ie=UTF-8",
    "https://www.google.com/search?q=another+query&tbm=isch",
    "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=hello+word",
    "https://example.com/?url=https%3A%2F%2Fclean-me.com%2Fpath%3Fparam%3Dvalue",
    "http://redirect.com/?q=https%3A%2F%2Ffinal-destination.org%2F",
    "https://www.example.com/page?utm_source=email&utm_medium=campaign&ref=sidebar#section-1",
    "https://www.anothersite.org/article?id=123&si=12345",
    "https://www.fragment-only.net/page#bottom",
    "ftp://ftp.example.com/file.txt",
    "invalid-url-no-scheme.com",
    "http://malicious.com/<script>alert('xss')</script>",
    "https://www.linkedin.com/in/ahmad-ali-othman-5b503324a/?lipi=urn%3Ali%3Apage%3Ad_flagship3_feed%3BHk5GcUfuTNCs4Jnx7x6%2Bqw%3D%3D",
    "https://www.example.com/path/to/page?param1=value1&param2=value2",
    "https://www.example.com/just/a/path",
    "https://example.com/path#fragment",
    "https://example.com/path?query=value#fragment",
  ];
  urls.forEach(proccessUrl);
  Deno.exit(0);
}

if (import.meta.main) main();
