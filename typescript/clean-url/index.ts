import process from "node:process";
import { createInterface } from "node:readline";
import type { Result } from "lib-result";
import { Err, ErrFromUnknown, Ok } from "lib-result";

type CleanedUrl = { cleanedUrl: string; furtherCleanedUrl?: string };

async function input(prompt: string): Promise<string> {
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const plaintext = await new Promise<string>(resolve => {
    rl.question(prompt, answer => {
      resolve(answer);
    });
  });

  rl.close();
  return plaintext;
}

function logError(message: string): never {
  process.stderr.write("\x1b[31m[ERROR]\x1b[0m");
  process.stderr.write(` ${message}\n`);
  process.exit(1);
}

function cleanUrl(url: string): Result<CleanedUrl, Error> {
  try {
    if (/^http[^?]*\/search\?/.test(url)) {
      const parts = url.split("?");
      if (parts.length !== 2) {
        return Err(new Error("Invalid Google search URL format"));
      }
      let [part0, part1] = parts;

      part1 = `?${parts[1]}`;
      let tbm = "";
      if (/&tbm=/.test(url)) {
        tbm = part1.replace(/.*?[&?]tbm=/i, "");
        tbm = `&tbm=${tbm.replace(/&.*/, "")}`;
      }
      part1 = part1.replace(/.*?[&?]q=/i, "");
      part1 = part1.replace(/&.*/, "");
      return Ok({ cleanedUrl: `${part0}?q=${part1}${tbm}` });
    }
    if (/^https?:\/\/.*[&?]url=/.test(url)) {
      const cleaned = decodeURIComponent(
        url.replace(/.*?[&?]url=/i, "").replace(/&.*/, "")
      );
      const parts = cleaned.split(/[?#]/);
      return Ok({
        cleanedUrl: cleaned,
        furtherCleanedUrl: parts.length > 1 ? parts[0] : undefined,
      });
    }

    if (/^https?:\/\/.*\?.*=https?%3A%2F%2F/.test(url)) {
      const cleaned = decodeURIComponent(
        url.match(/=https?%3A%2F%2F[A-Za-z0-9-_.!~*'()%]*/)?.[0]?.slice(1) || ""
      );
      const parts = cleaned.split(/[?#]/);
      return Ok({
        cleanedUrl: cleaned,
        furtherCleanedUrl: parts.length > 1 ? parts[0] : undefined,
      });
    }

    const parts = url.split(/[?#]/);
    if (parts.length < 2) {
      return Ok({ cleanedUrl: url });
    }
    return Ok({ cleanedUrl: parts[0] as string });
  } catch (error) {
    return ErrFromUnknown(error);
  }
}

function validateUrl(url: unknown): Result<void, Error> {
  if (typeof url !== "string") {
    return Err(new Error("URL must be string"));
  }
  try {
    new URL(url);
    return Ok(undefined);
  } catch {
    return Err(new Error("Invalid URL"));
  }
}

function proccessUrl(url: string): Result<void, Error> {
  const disallowedCharPattern = /[<>"]/;
  const httpFtpPattern = /^(http:\/\/|https:\/\/|ftp:\/\/).*$/;

  const cleaned = cleanUrl(url);
  if (cleaned.isError()) {
    return Err(cleaned.error);
  }
  const { cleanedUrl, furtherCleanedUrl } = cleaned.unwrap();

  if (
    httpFtpPattern.test(cleanedUrl) &&
    !disallowedCharPattern.test(cleanedUrl)
  ) {
    process.stdout.write(`${furtherCleanedUrl ?? cleanedUrl}\n`);
    return Ok(undefined);
  }
  return Err(new Error("Unable to extract the link."));
}

export function testUrls(): void {
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
  for (const u of urls) {
    const r = proccessUrl(u);
    if (r.isError())
      process.stderr.write(`\x1b[31m[ERROR]\x1b[0m ${r.error.message}\n`);
  }
}

async function main() {
  const url = process.argv.at(2) || (await input("Enter a URL to clean: "));
  if (!url.trim()) {
    logError("No URL provided. Usage: clean-url <URL>");
  }

  if (url.trim() === "--test") {
    testUrls();
    process.exit(0);
  }

  const v = validateUrl(url);
  if (v.isError()) logError(v.error.message);

  const p = proccessUrl(url);
  if (p.isError()) logError(p.error.message);
}

if (import.meta.main) main();
