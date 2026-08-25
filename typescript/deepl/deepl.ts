const HELP = `deepl - DeepL translation CLI (agent-friendly)

Usage:
  deepl translate <text...> --to <LANG> [--from <LANG>] [--context <text>] [--formality <level>] [--input-file <path>] [--output-file <path>] [--json] [--verbose] [--api-key <key>]
  deepl list [--json] [--api-key <key>]
  deepl --help | deepl translate --help | deepl list --help

Commands:
  translate   Translate text (default: plain stdout, one line per input)
  list        List supported languages (from GET /v3/languages)

Options (translate):
  --to <LANG>          Target language (required, e.g. DE, FR, JA, EN-US)
  --from <LANG>        Source language (optional, auto-detect if omitted)
  --context <text>     Extra context to improve accuracy (not translated, not billed)
  --formality <level>  default|more|less|prefer_more|prefer_less
  --input-file <path>  Read input from file (mutually exclusive with <text> args and stdin)
  --output-file <path> Write output to file instead of stdout
  --json               Machine-readable JSON output
  --verbose            Include billed_characters/model_type in stderr/json
  --api-key <key>      Override DEEPL_API_KEY env var

Env:
  DEEPL_API_KEY  API key (or set in typescript/deepl/.env). Key ending :fx uses api-free.deepl.com
`;

async function loadDotEnv(): Promise<void> {
  // ponytail: .env is relative to script path (~/scripts/typescript/deepl/.env), not CWD
  try {
    const scriptDir = new URL(".", import.meta.url).pathname;
    const envPath = `${scriptDir}.env`;
    const text = await Deno.readTextFile(envPath);
    for (const line of text.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eq = trimmed.indexOf("=");
      if (eq === -1) continue;
      const k = trimmed.slice(0, eq).trim();
      const v = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, "").trim();
      if (k === "DEEPL_API_KEY" && Deno.env.get(k) === undefined) {
        Deno.env.set(k, v);
      }
    }
  } catch {
    // no .env is fine
  }
}

function resolveApiKey(flagKey?: string): string {
  if (flagKey !== undefined) {
    const t = flagKey.trim();
    if (t) return t;
  } else {
    const envKey = Deno.env.get("DEEPL_API_KEY");
    if (envKey !== undefined) {
      const t = envKey.trim();
      if (t) return t;
    }
  }
  console.error("ERROR: DEEPL_API_KEY not set. Use --api-key <key> or set DEEPL_API_KEY env var or typescript/deepl/.env");
  Deno.exit(2);
}

function resolveBaseUrl(key: string): string {
  return key.endsWith(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com";
}

function parseApiKeyFlag(argv: string[]): string | undefined {
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--api-key") {
      const val = argv[i + 1];
      if (!val || val.startsWith("-")) {
        console.error("ERROR: --api-key requires a value");
        console.log(HELP);
        Deno.exit(1);
      }
      return val;
    }
    if (arg.startsWith("--api-key=")) {
      const val = arg.slice("--api-key=".length);
      if (!val) {
        console.error("ERROR: --api-key requires a value");
        console.log(HELP);
        Deno.exit(1);
      }
      return val;
    }
  }
  return undefined;
}

async function main(): Promise<void> {
  if (Deno.args.includes("--help") || Deno.args.includes("-h") || Deno.args.length === 0) {
    console.log(HELP);
    Deno.exit(0);
  }
  const sub = Deno.args[0];
  if ((sub === "translate" || sub === "list") && Deno.args.includes("--help")) {
    console.log(HELP);
    Deno.exit(0);
  }

  const flagKey = parseApiKeyFlag(Deno.args);
  await loadDotEnv();
  const apiKey = resolveApiKey(flagKey);
  const baseUrl = resolveBaseUrl(apiKey);
  // Task 2 stub: auth resolved, no network yet. baseUrl will be used in Task 3.
  void baseUrl;
  console.log(HELP);
}

await main();
