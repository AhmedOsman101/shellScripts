import { fstatSync, statSync } from "node:fs";
import {
  type Formality,
  type Language,
  type SourceLanguageCode,
  type TargetLanguageCode,
  type TextResult,
  type TranslateTextOptions,
  Translator,
} from "deepl-node";

const HELP = `deepl - DeepL translation CLI (agent-friendly)

Usage:
  deepl translate <text...> --to <LANG> [--from <LANG>] [--context <text>] [--formality <level>] [--input-file <path>] [--output-file <path>] [--json] [--verbose] [--api-key <key>]
  deepl list [--json] [--api-key <key>]
  deepl usage [--json] [--api-key <key>]
  deepl --help | deepl translate --help | deepl list --help | deepl usage --help

Commands:
  translate   Translate text (default: plain stdout, one line per input)
  list        List supported languages (via deepl-node)
  usage       Show billing period character usage (character_count / character_limit)

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

const TRANSLATE_HELP = `deepl translate - translate text via DeepL

Usage:
  deepl translate <text...> --to <LANG> [--from <LANG>] [--context <text>] [--formality <level>] [--input-file <path>] [--output-file <path>] [--json] [--verbose] [--api-key <key>]
  echo "text" | deepl translate --to <LANG> [...]
  deepl translate --input-file <path> --to <LANG> [...]

Options:
  --to <LANG>          Target language (required, e.g. DE, FR, JA, EN-US)
  --from <LANG>        Source language (optional, auto-detect if omitted)
  --context <text>     Extra context to improve accuracy (not translated, not billed)
  --formality <level>  default|more|less|prefer_more|prefer_less
  --input-file <path>  Read input from file (mutually exclusive with <text> args and stdin)
  --output-file <path> Write output to file instead of stdout
  --json               Machine-readable JSON output
  --verbose            Include billed_characters/model_type in stderr/json
  --api-key <key>      Override DEEPL_API_KEY env var
  --help, -h           Show this help

Env:
  DEEPL_API_KEY  API key (or set in typescript/deepl/.env). Key ending :fx uses api-free.deepl.com

Examples:
  deepl translate "Hello" --to DE
  echo "Hello" | deepl translate --to FR
  deepl translate --input-file input.txt --to DE --output-file out.txt
`;

const LIST_HELP = `deepl list - list supported languages

Usage:
  deepl list [--json] [--api-key <key>]

Options:
  --json               Machine-readable JSON output (raw API response)
  --api-key <key>      Override DEEPL_API_KEY env var
  --help, -h           Show this help

Env:
  DEEPL_API_KEY  API key (or set in typescript/deepl/.env). Key ending :fx uses api-free.deepl.com

Output:
  Plain: CODE<TAB>NAME per line, e.g. DE<TAB>German, with [N languages] to stderr
  JSON:  Raw API response from GET /v3/languages
`;

const USAGE_HELP = `deepl usage - show billing period usage

Usage:
  deepl usage [--json] [--api-key <key>]

Options:
  --json               Machine-readable JSON output
  --api-key <key>      Override DEEPL_API_KEY env var
  --help, -h           Show this help

Env:
  DEEPL_API_KEY  API key (or set in typescript/deepl/.env). Key ending :fx uses api-free.deepl.com

Output:
  Plain: character_count / character_limit and usage details to stdout
  JSON:  Raw Usage object from deepl-node (character/document/teamDocument)
`;

const FORMALITIES = new Set([
  "default",
  "more",
  "less",
  "prefer_more",
  "prefer_less",
]);

function printTranslateHelp(): never {
  console.log(TRANSLATE_HELP);
  process.exit(0);
}

function printListHelp(): never {
  console.log(LIST_HELP);
  process.exit(0);
}

function printUsageHelp(): never {
  console.log(USAGE_HELP);
  process.exit(0);
}

type TranslateOpts = {
  sourceLang?: string;
  targetLang: string;
  context?: string;
  formality?: string;
  showBilled?: boolean;
};
type Translation = {
  text: string;
  detected_source_language: string;
  billed_characters?: number;
  model_type_used?: string;
};

async function loadDotEnv(): Promise<void> {
  // ponytail: .env is relative to script path (~/scripts/typescript/deepl/.env), not CWD;
  // compiled bin/deepl needs fallbacks (cwd + execPath) since import.meta.url is embedded.
  const candidates: string[] = [];
  try {
    const scriptDir = new URL(".", import.meta.url).pathname;
    candidates.push(`${scriptDir}.env`);
  } catch {
    /* ignore */
  }
  try {
    candidates.push(`${process.cwd()}/typescript/deepl/.env`);
  } catch {
    /* ignore */
  }
  try {
    const execPath = process.execPath;
    const slash = execPath.lastIndexOf("/");
    if (slash !== -1) {
      const execDir = execPath.slice(0, slash);
      candidates.push(`${execDir}/../typescript/deepl/.env`);
      candidates.push(`${execDir}/typescript/deepl/.env`);
    }
  } catch {
    /* ignore */
  }
  try {
    const scriptsDir = process.env.SCRIPTS_DIR;
    if (scriptsDir) candidates.push(`${scriptsDir}/typescript/deepl/.env`);
  } catch {
    /* ignore */
  }

  for (const envPath of candidates) {
    try {
      const text = await Bun.file(envPath).text();
      for (const line of text.split("\n")) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#")) continue;
        const eq = trimmed.indexOf("=");
        if (eq === -1) continue;
        const k = trimmed.slice(0, eq).trim();
        const v = trimmed
          .slice(eq + 1)
          .trim()
          .replace(/^["']|["']$/g, "")
          .trim();
        if (k === "DEEPL_API_KEY" && process.env[k] === undefined) {
          process.env[k] = v;
        }
      }
      if (process.env.DEEPL_API_KEY !== undefined) return;
    } catch {
      /* try next */
    }
  }
}

function resolveApiKey(flagKey?: string): string {
  if (flagKey !== undefined) {
    const t = flagKey.trim();
    if (t) return t;
    console.error("ERROR: --api-key value is empty");
    process.exit(1);
  }
  const envKey = process.env["DEEPL_API_KEY"];
  if (envKey !== undefined) {
    const t = envKey.trim();
    if (t) return t;
  }
  console.error(
    "ERROR: DEEPL_API_KEY not set. Use --api-key <key> or set DEEPL_API_KEY env var or typescript/deepl/.env"
  );
  process.exit(2);
}

function resolveBaseUrl(key: string): string {
  return key.endsWith(":fx")
    ? "https://api-free.deepl.com"
    : "https://api.deepl.com";
}

async function translateTexts(
  texts: string[],
  opts: TranslateOpts,
  apiKey: string,
  _baseUrl?: string
): Promise<Translation[]> {
  // Use official deepl-node library — handles :fx auto-detection, retries, and typed results.
  // ponytail: 128 KiB is request body limit; chunk on our own to stay under it.
  // Estimate JSON overhead ~ 100 bytes per text + keys; use 120 KiB safe threshold.
  const MAX_BYTES = 120 * 1024;
  const encoder = new TextEncoder();

  function estimateJsonSize(chunk: string[]): number {
    // Rough: JSON.stringify({text: chunk, target_lang: "XX"}) length
    return (
      encoder.encode(
        JSON.stringify({ text: chunk, target_lang: opts.targetLang })
      ).length + 2048
    );
  }

  const chunks: string[][] = [];
  let current: string[] = [];
  for (const t of texts) {
    const tBytes = encoder.encode(t).length;
    if (tBytes > MAX_BYTES) {
      if (current.length) {
        chunks.push(current);
        current = [];
      }
      // Split single huge text by lines to avoid breaking API; preserve order.
      let remaining = t;
      while (remaining.length) {
        let slice = remaining.slice(0, MAX_BYTES - 100);
        // Prefer split at newline to keep sentences intact
        if (remaining.length > slice.length) {
          const nl = slice.lastIndexOf("\n");
          if (nl > 0) slice = slice.slice(0, nl + 1);
        }
        const piece = slice;
        chunks.push([piece]);
        remaining = remaining.slice(piece.length);
        if (remaining.length === 0) break;
      }
      continue;
    }
    const candidate = [...current, t];
    if (estimateJsonSize(candidate) > MAX_BYTES) {
      chunks.push(current);
      current = [t];
    } else {
      current = candidate;
    }
  }
  if (current.length) chunks.push(current);

  const translator = new Translator(apiKey);
  const all: Translation[] = [];
  for (const chunk of chunks) {
    try {
      const input = chunk.length === 1 ? chunk[0] : chunk;
      const sourceLang = (opts.sourceLang ?? null) as SourceLanguageCode | null;
      const targetLang = opts.targetLang as TargetLanguageCode;
      const res = await translator.translateText(
        input as string & string[],
        sourceLang,
        targetLang,
        {
          formality: opts.formality as Formality | undefined,
          context: opts.context,
        } as TranslateTextOptions
      );
      const arr = Array.isArray(res) ? res : [res];
      for (const r of arr as TextResult[]) {
        all.push({
          text: r.text,
          detected_source_language: r.detectedSourceLang.toUpperCase(),
          billed_characters: r.billedCharacters,
          model_type_used: (r as unknown as { modelTypeUsed?: string })
            .modelTypeUsed,
        });
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      const lower = msg.toLowerCase();
      if (lower.includes("quota") || lower.includes("456")) {
        console.error(`ERROR: DeepL API quota exceeded — ${msg}`);
        process.exit(3);
      }
      if (
        lower.includes("authorization") ||
        lower.includes("403") ||
        lower.includes("forbidden")
      ) {
        console.error(
          `ERROR: DeepL API 403 Forbidden — check DEEPL_API_KEY and :fx vs pro endpoint — ${msg}`
        );
        process.exit(2);
      }
      // DeepLError may contain status; try to extract
      console.error(`ERROR: DeepL API error — ${msg}`);
      process.exit(2);
    }
  }
  return all;
}

function parseTranslateArgs(argv: string[]): {
  texts: string[];
  opts: TranslateOpts;
  inputFile?: string;
  outputFile?: string;
  json: boolean;
  verbose: boolean;
  apiKeyFlag?: string;
} {
  const texts: string[] = [];
  let targetLang = "";
  let sourceLang: string | undefined;
  let context: string | undefined;
  let formality: string | undefined;
  let inputFile: string | undefined;
  let outputFile: string | undefined;
  let json = false;
  let verbose = false;
  let apiKeyFlag: string | undefined;

  function fail(msg: string): never {
    console.error(`ERROR: ${msg}`);
    console.log(TRANSLATE_HELP);
    process.exit(1);
  }

  function needValue(
    key: string,
    val: string | undefined,
    nextIdx: number
  ): { value: string; consumed: number } {
    if (val !== undefined) {
      if (!val) fail(`${key} requires a value`);
      return { value: val, consumed: 0 };
    }
    const nxt = argv[nextIdx];
    if (!nxt || nxt.startsWith("-")) fail(`${key} requires a value`);
    return { value: nxt, consumed: 1 };
  }

  let i = 0;
  while (i < argv.length) {
    const arg: string = argv[i] as string;
    if (arg === "--help" || arg === "-h") {
      printTranslateHelp();
    }
    if (arg.startsWith("--")) {
      const eqIdx = arg.indexOf("=");
      let key: string;
      let val: string | undefined;
      if (eqIdx !== -1) {
        key = arg.slice(0, eqIdx);
        val = arg.slice(eqIdx + 1);
      } else {
        key = arg;
        val = undefined;
      }
      switch (key) {
        case "--to": {
          const r = needValue(key, val, i + 1);
          targetLang = r.value;
          i += r.consumed;
          break;
        }
        case "--from": {
          const r = needValue(key, val, i + 1);
          sourceLang = r.value;
          i += r.consumed;
          break;
        }
        case "--context": {
          const r = needValue(key, val, i + 1);
          context = r.value;
          i += r.consumed;
          break;
        }
        case "--formality": {
          const r = needValue(key, val, i + 1);
          formality = r.value;
          i += r.consumed;
          break;
        }
        case "--input-file": {
          const r = needValue(key, val, i + 1);
          inputFile = r.value;
          i += r.consumed;
          break;
        }
        case "--output-file": {
          const r = needValue(key, val, i + 1);
          outputFile = r.value;
          i += r.consumed;
          break;
        }
        case "--api-key": {
          const r = needValue(key, val, i + 1);
          apiKeyFlag = r.value;
          i += r.consumed;
          break;
        }
        case "--json": {
          if (val !== undefined) fail(`unknown flag "${arg}"`);
          json = true;
          break;
        }
        case "--verbose": {
          if (val !== undefined) fail(`unknown flag "${arg}"`);
          verbose = true;
          break;
        }
        case "--help":
          printTranslateHelp();
        default:
          fail(`unknown flag "${key}"`);
      }
    } else if (arg.startsWith("-")) {
      fail(`unknown flag "${arg}"`);
    } else {
      texts.push(arg);
    }
    i++;
  }

  const opts: TranslateOpts = { targetLang };
  if (sourceLang) opts.sourceLang = sourceLang;
  if (context) opts.context = context;
  if (formality) opts.formality = formality;
  if (json || verbose) opts.showBilled = true;

  return { texts, opts, inputFile, outputFile, json, verbose, apiKeyFlag };
}

function isPipeInput(): boolean {
  if (process.stdin.isTTY) return false;
  // deterministic pipe detection — stat isFifo/isFile vs isCharDevice distinguishes pipe/file from /dev/null
  try {
    const s = fstatSync(0); // fd 0 = stdin
    if (s.isFIFO() || s.isFile()) return true;
    if (s.isCharacterDevice()) return false;
  } catch {
    /* fallback to path stat */
  }
  for (const p of ["/proc/self/fd/0", "/dev/stdin"]) {
    try {
      const s = statSync(p);
      if (s.isFIFO() || s.isFile()) return true;
      if (s.isCharacterDevice()) return false;
      if (s.isSocket()) return true;
      return false;
    } catch {
      /* try next */
    }
  }
  return true;
}

async function readPipedStdin(): Promise<string | null> {
  if (!isPipeInput()) return null;
  const reader = Bun.stdin.stream().getReader();
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      if (value) chunks.push(value);
    }
  } finally {
    try {
      reader.releaseLock();
    } catch {
      /* ignore */
    }
  }
  if (chunks.length === 0) return "";
  const total = chunks.reduce((a, b) => a + b.length, 0);
  const all = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) {
    all.set(c, off);
    off += c.length;
  }
  return new TextDecoder().decode(all);
}

async function resolveInputTexts(
  positional: string[],
  inputFile?: string
): Promise<string[]> {
  const hasPositional = positional.length > 0;
  const hasFile = !!inputFile;
  // ponytail: deterministic pipe detection via isTerminal + stat(isFifo/isFile vs isCharDevice)
  const pipedBuf = await readPipedStdin();
  const isPipe = pipedBuf !== null;

  if (hasPositional && hasFile) {
    console.error("ERROR: <text> args and --input-file are mutually exclusive");
    process.exit(1);
  }
  if (hasFile && isPipe) {
    console.error("ERROR: --input-file and piped stdin are mutually exclusive");
    process.exit(1);
  }
  if (hasPositional && isPipe) {
    console.error("ERROR: <text> args and piped stdin are mutually exclusive");
    process.exit(1);
  }
  if (hasFile) {
    try {
      const content = await Bun.file(inputFile).text();
      const texts = [content]; // one unit, preserve newlines
      if (new TextEncoder().encode(texts.join("\n")).length > 128 * 1024) {
        console.error("WARN: request near 128KiB limit — DeepL may reject");
      }
      return texts;
    } catch (e) {
      console.error(`ERROR: failed to read --input-file "${inputFile}": ${e}`);
      process.exit(1);
    }
  }
  if (hasPositional) {
    if (new TextEncoder().encode(positional.join("\n")).length > 128 * 1024) {
      console.error("WARN: request near 128KiB limit — DeepL may reject");
    }
    return positional;
  }
  if (isPipe) {
    const buf = pipedBuf!;
    const trimmed = buf.trim();
    if (!trimmed) {
      console.error("ERROR: no input from stdin");
      process.exit(1);
    }
    if (new TextEncoder().encode(buf).length > 128 * 1024) {
      console.error("WARN: request near 128KiB limit — DeepL may reject");
    }
    return [buf];
  }
  console.error(
    "ERROR: no input — provide <text> args, --input-file <path>, or pipe stdin"
  );
  process.exit(1);
}

async function renderOutput(
  translations: Translation[],
  opts: { json: boolean; verbose: boolean; outputFile?: string }
): Promise<void> {
  let out: string;
  if (opts.json) {
    out = `${JSON.stringify({ translations }, null, 2)}\n`;
  } else {
    out = `${translations.map(t => t.text).join("\n")}\n`;
    if (opts.verbose) {
      const meta = translations
        .map(
          t =>
            `[detected:${t.detected_source_language}${t.billed_characters ? ` billed:${t.billed_characters}` : ""}${t.model_type_used ? ` model:${t.model_type_used}` : ""}]`
        )
        .join(" ");
      console.error(meta);
    } else {
      // always emit concise detected lang to stderr for LLM info without polluting stdout
      const detected = translations
        .map(t => t.detected_source_language)
        .join(",");
      console.error(`[detected: ${detected}]`);
    }
  }
  if (opts.outputFile) {
    await Bun.write(opts.outputFile, out);
  } else {
    process.stdout.write(out);
  }
}

async function listLanguages(
  apiKey: string,
  _baseUrl: string,
  jsonMode: boolean
) {
  // Use deepl-node where possible — library handles auth and endpoint.
  // Note: deepl-node@1.28 still uses GET /v2/languages internally (deprecated,
  // will migrate to /v3/languages by Q2 2026 per migration guide). Keeping
  // library usage here removes raw fetch; raw v3 fetch is kept only where
  // library cannot do it (none currently for languages).
  const translator = new Translator(apiKey);
  try {
    const [source, target] = await Promise.all([
      translator.getSourceLanguages(),
      translator.getTargetLanguages(),
    ]);
    const map = new Map<string, Language>();
    for (const l of [...source, ...target]) {
      if (!map.has(l.code)) map.set(l.code, l);
    }
    const rows = [...map.values()].sort((a, b) => a.code.localeCompare(b.code));
    if (jsonMode) {
      console.log(JSON.stringify(rows, null, 2));
      return;
    }
    for (const r of rows) console.log(`${r.code}\t${r.name}`);
    console.error(`[${rows.length} languages]`);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error(`ERROR: failed to list languages: ${msg}`);
    process.exit(2);
  }
}

async function showUsage(apiKey: string, _baseUrl: string, jsonMode: boolean) {
  const translator = new Translator(apiKey);
  try {
    const usage = await translator.getUsage();
    if (jsonMode) {
      // Raw JSON for agent: expose character/document/teamDocument
      const out: Record<string, unknown> = {};
      if (usage.character)
        out.character = {
          count: usage.character.count,
          limit: usage.character.limit,
        };
      if (usage.document)
        out.document = {
          count: usage.document.count,
          limit: usage.document.limit,
        };
      if (usage.teamDocument)
        out.teamDocument = {
          count: usage.teamDocument.count,
          limit: usage.teamDocument.limit,
        };
      // Also include top-level for compatibility with /v2/usage raw shape
      console.log(JSON.stringify(out, null, 2));
      return;
    }
    // Plain LLM-friendly: character 1423/1000000 (0.14%)
    if (usage.character) {
      const pct = usage.character.limit
        ? ((usage.character.count / usage.character.limit) * 100).toFixed(2)
        : "0";
      console.log(
        `character: ${usage.character.count}/${usage.character.limit} (${pct}%)`
      );
    }
    if (usage.document) {
      const pct = usage.document.limit
        ? ((usage.document.count / usage.document.limit) * 100).toFixed(2)
        : "0";
      console.log(
        `document: ${usage.document.count}/${usage.document.limit} (${pct}%)`
      );
    }
    if (usage.teamDocument) {
      const pct = usage.teamDocument.limit
        ? ((usage.teamDocument.count / usage.teamDocument.limit) * 100).toFixed(
            2
          )
        : "0";
      console.log(
        `teamDocument: ${usage.teamDocument.count}/${usage.teamDocument.limit} (${pct}%)`
      );
    }
    if (!usage.character && !usage.document && !usage.teamDocument) {
      console.log("No usage data");
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const lower = msg.toLowerCase();
    if (lower.includes("quota") || lower.includes("456")) {
      console.error(`ERROR: quota exceeded — ${msg}`);
      process.exit(3);
    }
    console.error(`ERROR: failed to get usage: ${msg}`);
    process.exit(2);
  }
}

async function main(): Promise<void> {
  if (process.argv.length === 2) {
    console.log(HELP);
    process.exit(0);
  }
  const sub = process.argv[2];
  if (sub === "--help" || sub === "-h") {
    console.log(HELP);
    process.exit(0);
  }
  if (
    sub === "translate" &&
    (process.argv.includes("--help") || process.argv.includes("-h"))
  ) {
    printTranslateHelp();
  }
  if (
    sub === "list" &&
    (process.argv.includes("--help") || process.argv.includes("-h"))
  ) {
    printListHelp();
  }
  if (
    sub === "usage" &&
    (process.argv.includes("--help") || process.argv.includes("-h"))
  ) {
    printUsageHelp();
  }
  // generic --help for no subcommand (e.g. `deepl --help`)
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    console.log(HELP);
    process.exit(0);
  }

  if (sub === "translate") {
    const parsed = parseTranslateArgs(process.argv.slice(3));

    if (!parsed.opts.targetLang) {
      console.error("ERROR: --to <LANG> is required");
      console.log(TRANSLATE_HELP);
      process.exit(1);
    }

    if (parsed.opts.formality && !FORMALITIES.has(parsed.opts.formality)) {
      console.error(
        `ERROR: --formality must be one of ${[...FORMALITIES].join("|")}`
      );
      process.exit(1);
    }

    const texts = await resolveInputTexts(parsed.texts, parsed.inputFile);

    await loadDotEnv();
    const apiKey = resolveApiKey(parsed.apiKeyFlag);
    const baseUrl = resolveBaseUrl(apiKey);

    const translations = await translateTexts(
      texts,
      parsed.opts,
      apiKey,
      baseUrl
    );

    await renderOutput(translations, {
      json: parsed.json,
      verbose: parsed.verbose,
      outputFile: parsed.outputFile,
    });
    return;
  }

  if (sub === "list") {
    const args = process.argv.slice(3);
    if (args.includes("--help") || args.includes("-h")) {
      printListHelp();
    }
    let jsonMode = false;
    let flagKey: string | undefined;
    for (let i = 0; i < args.length; i++) {
      const arg = args[i];
      if (arg === "--json") {
        jsonMode = true;
      } else if (arg === "--api-key") {
        const nxt = args[i + 1];
        if (!nxt || nxt.startsWith("-")) {
          console.error("ERROR: --api-key requires a value");
          console.log(LIST_HELP);
          process.exit(1);
        }
        flagKey = nxt;
        i++;
      } else if (arg.startsWith("--api-key=")) {
        const val = arg.slice("--api-key=".length);
        if (!val) {
          console.error("ERROR: --api-key requires a value");
          console.log(LIST_HELP);
          process.exit(1);
        }
        flagKey = val;
      } else if (arg.startsWith("-")) {
        console.error(`ERROR: unknown flag "${arg}"`);
        console.log(LIST_HELP);
        process.exit(1);
      } else {
        console.error(`ERROR: unknown argument "${arg}"`);
        console.log(LIST_HELP);
        process.exit(1);
      }
    }
    await loadDotEnv();
    const apiKey = resolveApiKey(flagKey);
    const baseUrl = resolveBaseUrl(apiKey);
    await listLanguages(apiKey, baseUrl, jsonMode);
    return;
  }

  if (sub === "usage") {
    const args = process.argv.slice(3);
    if (args.includes("--help") || args.includes("-h")) {
      printUsageHelp();
    }
    let jsonMode = false;
    let flagKey: string | undefined;
    for (let i = 0; i < args.length; i++) {
      const arg = args[i];
      if (arg === "--json") {
        jsonMode = true;
      } else if (arg === "--api-key") {
        const nxt = args[i + 1];
        if (!nxt || nxt.startsWith("-")) {
          console.error("ERROR: --api-key requires a value");
          console.log(USAGE_HELP);
          process.exit(1);
        }
        flagKey = nxt;
        i++;
      } else if (arg.startsWith("--api-key=")) {
        const val = arg.slice("--api-key=".length);
        if (!val) {
          console.error("ERROR: --api-key requires a value");
          console.log(USAGE_HELP);
          process.exit(1);
        }
        flagKey = val;
      } else if (arg.startsWith("-")) {
        console.error(`ERROR: unknown flag "${arg}"`);
        console.log(USAGE_HELP);
        process.exit(1);
      } else {
        console.error(`ERROR: unknown argument "${arg}"`);
        console.log(USAGE_HELP);
        process.exit(1);
      }
    }
    await loadDotEnv();
    const apiKey = resolveApiKey(flagKey);
    const baseUrl = resolveBaseUrl(apiKey);
    await showUsage(apiKey, baseUrl, jsonMode);
    return;
  }

  console.error(`ERROR: unknown command "${sub}"`);
  console.log(HELP);
  process.exit(1);
}

await main();
