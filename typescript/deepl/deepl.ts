import * as deepl from "deepl-node";

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

const FORMALITIES = new Set([
  "default",
  "more",
  "less",
  "prefer_more",
  "prefer_less",
]);

function printTranslateHelp(): never {
  console.log(TRANSLATE_HELP);
  Deno.exit(0);
}

function printListHelp(): never {
  console.log(LIST_HELP);
  Deno.exit(0);
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
    candidates.push(`${Deno.cwd()}/typescript/deepl/.env`);
  } catch {
    /* ignore */
  }
  try {
    const execPath = Deno.execPath();
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
    const scriptsDir = Deno.env.get("SCRIPTS_DIR");
    if (scriptsDir) candidates.push(`${scriptsDir}/typescript/deepl/.env`);
  } catch {
    /* ignore */
  }

  for (const envPath of candidates) {
    try {
      const text = await Deno.readTextFile(envPath);
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
        if (k === "DEEPL_API_KEY" && Deno.env.get(k) === undefined) {
          Deno.env.set(k, v);
        }
      }
      if (Deno.env.get("DEEPL_API_KEY") !== undefined) return;
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
    Deno.exit(1);
  }
  const envKey = Deno.env.get("DEEPL_API_KEY");
  if (envKey !== undefined) {
    const t = envKey.trim();
    if (t) return t;
  }
  console.error(
    "ERROR: DEEPL_API_KEY not set. Use --api-key <key> or set DEEPL_API_KEY env var or typescript/deepl/.env"
  );
  Deno.exit(2);
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

  const translator = new deepl.Translator(apiKey);
  const all: Translation[] = [];
  for (const chunk of chunks) {
    try {
      const input = chunk.length === 1 ? chunk[0] : chunk;
      const sourceLang = (opts.sourceLang ??
        null) as deepl.SourceLanguageCode | null;
      const targetLang = opts.targetLang as deepl.TargetLanguageCode;
      const res = await translator.translateText(
        input as string & string[],
        sourceLang,
        targetLang,
        {
          formality: opts.formality as deepl.Formality | undefined,
          context: opts.context,
        } as deepl.TranslateTextOptions
      );
      const arr = Array.isArray(res) ? res : [res];
      for (const r of arr as deepl.TextResult[]) {
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
        Deno.exit(3);
      }
      if (
        lower.includes("authorization") ||
        lower.includes("403") ||
        lower.includes("forbidden")
      ) {
        console.error(
          `ERROR: DeepL API 403 Forbidden — check DEEPL_API_KEY and :fx vs pro endpoint — ${msg}`
        );
        Deno.exit(2);
      }
      // DeepLError may contain status; try to extract
      console.error(`ERROR: DeepL API error — ${msg}`);
      Deno.exit(2);
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
    Deno.exit(1);
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
    const arg = argv[i];
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
        case "--help": {
          printTranslateHelp();
          break;
        }
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
  if (Deno.stdin.isTerminal()) return false;
  // ponytail: deterministic pipe detection — stat isFifo/isFile vs isCharDevice distinguishes pipe/file from /dev/null
  try {
    const maybeStat = (
      Deno.stdin as unknown as { statSync?: () => Deno.FileInfo }
    ).statSync;
    if (typeof maybeStat === "function") {
      const s = maybeStat.call(Deno.stdin) as Deno.FileInfo;
      if (s.isFifo || s.isFile) return true;
      if (s.isCharDevice) return false;
    }
  } catch {
    /* fallback to path stat */
  }
  for (const p of ["/proc/self/fd/0", "/dev/stdin"]) {
    try {
      const s = Deno.statSync(p);
      if (s.isFifo || s.isFile) return true;
      if (s.isCharDevice) return false;
      const isSocket = (s as unknown as { isSocket: boolean }).isSocket;
      if (isSocket) return true;
      return false;
    } catch {
      /* try next */
    }
  }
  return true;
}

async function readPipedStdin(): Promise<string | null> {
  if (!isPipeInput()) return null;
  const reader = Deno.stdin.readable.getReader();
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
    Deno.exit(1);
  }
  if (hasFile && isPipe) {
    console.error("ERROR: --input-file and piped stdin are mutually exclusive");
    Deno.exit(1);
  }
  if (hasPositional && isPipe) {
    console.error("ERROR: <text> args and piped stdin are mutually exclusive");
    Deno.exit(1);
  }
  if (hasFile) {
    try {
      const content = await Deno.readTextFile(inputFile!);
      const texts = [content]; // one unit, preserve newlines
      if (new TextEncoder().encode(texts.join("\n")).length > 128 * 1024) {
        console.error("WARN: request near 128KiB limit — DeepL may reject");
      }
      return texts;
    } catch (e) {
      console.error(`ERROR: failed to read --input-file "${inputFile}": ${e}`);
      Deno.exit(1);
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
      Deno.exit(1);
    }
    if (new TextEncoder().encode(buf).length > 128 * 1024) {
      console.error("WARN: request near 128KiB limit — DeepL may reject");
    }
    return [buf];
  }
  console.error(
    "ERROR: no input — provide <text> args, --input-file <path>, or pipe stdin"
  );
  Deno.exit(1);
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
    await Deno.writeTextFile(opts.outputFile, out);
  } else {
    await Deno.stdout.write(new TextEncoder().encode(out));
  }
}

async function listLanguages(
  apiKey: string,
  baseUrl: string,
  jsonMode: boolean
) {
  // Use only v3 — /v2/languages is deprecated (see migration guide)
  const url = `${baseUrl}/v3/languages?resource=translate_text`;
  let data: unknown = null;
  let lastErr = "";
  try {
    const res = await fetch(url, {
      headers: { Authorization: `DeepL-Auth-Key ${apiKey}` },
    });
    if (res.ok) {
      data = await res.json();
    } else {
      lastErr = `${res.status} ${await res.text().catch(() => "")}`;
    }
  } catch (e) {
    lastErr = e instanceof Error ? e.message : String(e);
  }
  if (!data) {
    console.error(`ERROR: failed to list languages: ${lastErr}`);
    Deno.exit(2);
  }

  if (jsonMode) {
    console.log(JSON.stringify(data, null, 2));
    return;
  }
  // data is array of {language, name, supports_formality?} or v3 shape — handle both
  type LangRow = {
    code?: string;
    language?: string;
    lang?: string;
    name?: string;
  };
  const rows = Array.isArray(data)
    ? (data as LangRow[])
    : ((data as { languages?: LangRow[] }).languages ?? []);
  // LLM-friendly table: CODE  NAME
  for (const r of rows) {
    const code = r.code ?? r.language ?? r.lang ?? "";
    const name = r.name ?? code;
    console.log(`${code}\t${name}`);
  }
  console.error(`[${rows.length} languages]`);
}

async function main(): Promise<void> {
  if (Deno.args.length === 0) {
    console.log(HELP);
    Deno.exit(0);
  }
  const sub = Deno.args[0];
  if (sub === "--help" || sub === "-h") {
    console.log(HELP);
    Deno.exit(0);
  }
  if (
    sub === "translate" &&
    (Deno.args.includes("--help") || Deno.args.includes("-h"))
  ) {
    printTranslateHelp();
  }
  if (
    sub === "list" &&
    (Deno.args.includes("--help") || Deno.args.includes("-h"))
  ) {
    printListHelp();
  }
  // generic --help for no subcommand (e.g. `deepl --help`)
  if (Deno.args.includes("--help") || Deno.args.includes("-h")) {
    console.log(HELP);
    Deno.exit(0);
  }

  if (sub === "translate") {
    const parsed = parseTranslateArgs(Deno.args.slice(1));

    if (!parsed.opts.targetLang) {
      console.error("ERROR: --to <LANG> is required");
      console.log(TRANSLATE_HELP);
      Deno.exit(1);
    }

    if (parsed.opts.formality && !FORMALITIES.has(parsed.opts.formality)) {
      console.error(
        `ERROR: --formality must be one of ${[...FORMALITIES].join("|")}`
      );
      Deno.exit(1);
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
    const args = Deno.args.slice(1);
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
          Deno.exit(1);
        }
        flagKey = nxt;
        i++;
      } else if (arg.startsWith("--api-key=")) {
        const val = arg.slice("--api-key=".length);
        if (!val) {
          console.error("ERROR: --api-key requires a value");
          console.log(LIST_HELP);
          Deno.exit(1);
        }
        flagKey = val;
      } else if (arg.startsWith("-")) {
        console.error(`ERROR: unknown flag "${arg}"`);
        console.log(LIST_HELP);
        Deno.exit(1);
      } else {
        console.error(`ERROR: unknown argument "${arg}"`);
        console.log(LIST_HELP);
        Deno.exit(1);
      }
    }
    await loadDotEnv();
    const apiKey = resolveApiKey(flagKey);
    const baseUrl = resolveBaseUrl(apiKey);
    await listLanguages(apiKey, baseUrl, jsonMode);
    return;
  }

  console.error(`ERROR: unknown command "${sub}"`);
  console.log(HELP);
  Deno.exit(1);
}

await main();
