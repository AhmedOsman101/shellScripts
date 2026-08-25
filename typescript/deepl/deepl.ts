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

type TranslateOpts = { sourceLang?: string; targetLang: string; context?: string; formality?: string; showBilled?: boolean };
type Translation = { text: string; detected_source_language: string; billed_characters?: number; model_type_used?: string };

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

// deno-lint-ignore no-unused-vars
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

async function translateTexts(texts: string[], opts: TranslateOpts, apiKey: string, baseUrl: string): Promise<Translation[]> {
  const body: Record<string, unknown> = {
    text: texts,
    target_lang: opts.targetLang.toUpperCase(),
  };
  if (opts.sourceLang) body.source_lang = opts.sourceLang.toUpperCase();
  if (opts.context) body.context = opts.context;
  if (opts.formality) body.formality = opts.formality;
  if (opts.showBilled) body.show_billed_characters = true;
  // model_type omitted unless --model is added later (YAGNI)

  const res = await fetch(`${baseUrl}/v2/translate`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `DeepL-Auth-Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const trace = res.headers.get("X-Trace-ID") ?? "";
    const errBody = await res.text().catch(() => "");
    let msg = `DeepL API ${res.status} ${res.statusText}`;
    if (errBody) msg += `: ${errBody.slice(0, 500)}`;
    if (trace) msg += ` (X-Trace-ID: ${trace})`;
    if (res.status === 403) msg += " — check DEEPL_API_KEY and :fx vs pro endpoint";
    if (res.status === 456) msg += " — quota exceeded (free 500K/mo)";
    console.error(`ERROR: ${msg}`);
    Deno.exit(res.status === 456 ? 3 : res.status === 403 ? 2 : 2);
  }
  const data = await res.json() as { translations: Translation[] };
  return data.translations;
}

function parseTranslateArgs(argv: string[]): { texts: string[]; opts: TranslateOpts; inputFile?: string; outputFile?: string; json: boolean; verbose: boolean; apiKeyFlag?: string } {
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
    console.log(HELP);
    Deno.exit(1);
  }

  function needValue(key: string, val: string | undefined, nextIdx: number): { value: string; consumed: number } {
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
      console.log(HELP);
      Deno.exit(0);
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
          console.log(HELP);
          Deno.exit(0);
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

async function readPipedStdin(): Promise<string | null> {
  if (Deno.stdin.isTerminal()) return null;
  const reader = Deno.stdin.readable.getReader();
  try {
    const readPromise = reader.read().then((r) => ({ ...r, timeout: false as const }));
    const timeoutPromise = new Promise<{ timeout: true }>((res) => setTimeout(() => res({ timeout: true }), 50));
    const result = await Promise.race([readPromise, timeoutPromise]) as { done?: boolean; value?: Uint8Array; timeout?: boolean };
    if (result.timeout) {
      try { await reader.cancel(); } catch { /* ignore */ }
      return null;
    }
    if (result.done) {
      try { reader.releaseLock(); } catch { /* ignore */ }
      return null;
    }
    const chunks: Uint8Array[] = [result.value!];
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      chunks.push(value);
    }
    try { reader.releaseLock(); } catch { /* ignore */ }
    const total = chunks.reduce((a, b) => a + b.length, 0);
    const all = new Uint8Array(total);
    let off = 0;
    for (const c of chunks) { all.set(c, off); off += c.length; }
    return new TextDecoder().decode(all);
  } catch {
    try { reader.releaseLock(); } catch { /* ignore */ }
    return null;
  }
}

async function resolveInputTexts(positional: string[], inputFile?: string): Promise<string[]> {
  const hasPositional = positional.length > 0;
  const hasFile = !!inputFile;
  // ponytail: robust pipe detection — brief uses !isTerminal() but that is true for /dev/null in CI; peek distinguishes actual pipe/file redirect
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
  console.error("ERROR: no input — provide <text> args, --input-file <path>, or pipe stdin");
  Deno.exit(1);
}

async function renderOutput(translations: Translation[], opts: { json: boolean; verbose: boolean; outputFile?: string }): Promise<void> {
  let out: string;
  if (opts.json) {
    out = JSON.stringify({ translations }, null, 2) + "\n";
  } else {
    out = translations.map((t) => t.text).join("\n") + "\n";
    if (opts.verbose) {
      const meta = translations.map((t) =>
        `[detected:${t.detected_source_language}${t.billed_characters ? ` billed:${t.billed_characters}` : ""}${t.model_type_used ? ` model:${t.model_type_used}` : ""}]`
      ).join(" ");
      console.error(meta);
    } else {
      // always emit concise detected lang to stderr for LLM info without polluting stdout
      const detected = translations.map((t) => t.detected_source_language).join(",");
      console.error(`[detected: ${detected}]`);
    }
  }
  if (opts.outputFile) {
    await Deno.writeTextFile(opts.outputFile, out);
  } else {
    await Deno.stdout.write(new TextEncoder().encode(out));
  }
}

async function listLanguages(apiKey: string, baseUrl: string, jsonMode: boolean) {
  const endpoints = [
    `${baseUrl}/v3/languages?resource=translate_text`,
    `${baseUrl}/v2/languages`,
  ];
  let data: unknown = null;
  let lastErr = "";
  for (const url of endpoints) {
    try {
      const res = await fetch(url, { headers: { "Authorization": `DeepL-Auth-Key ${apiKey}` } });
      if (res.ok) { data = await res.json(); break; }
      lastErr = `${res.status} ${await res.text().catch(() => "")}`;
    } catch (e) {
      lastErr = e instanceof Error ? e.message : String(e);
    }
  }
  if (!data) { console.error(`ERROR: failed to list languages: ${lastErr}`); Deno.exit(2); }

  if (jsonMode) {
    console.log(JSON.stringify(data, null, 2));
    return;
  }
  // data is array of {language, name, supports_formality?} or v3 shape — handle both
  type LangRow = { code?: string; language?: string; lang?: string; name?: string };
  const rows = Array.isArray(data)
    ? data as LangRow[]
    : (data as { languages?: LangRow[] }).languages ?? [];
  // LLM-friendly table: CODE  NAME
  for (const r of rows) {
    const code = r.code ?? r.language ?? r.lang ?? "";
    const name = r.name ?? code;
    console.log(`${code}\t${name}`);
  }
  console.error(`[${rows.length} languages]`);
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

  if (sub === "translate") {
    const parsed = parseTranslateArgs(Deno.args.slice(1));

    if (!parsed.opts.targetLang) {
      console.error("ERROR: --to <LANG> is required");
      console.log(HELP);
      Deno.exit(1);
    }

    const texts = await resolveInputTexts(parsed.texts, parsed.inputFile);

    await loadDotEnv();
    const apiKey = resolveApiKey(parsed.apiKeyFlag);
    const baseUrl = resolveBaseUrl(apiKey);

    const translations = await translateTexts(texts, parsed.opts, apiKey, baseUrl);

    await renderOutput(translations, { json: parsed.json, verbose: parsed.verbose, outputFile: parsed.outputFile });
    return;
  }

  if (sub === "list") {
    const args = Deno.args.slice(1);
    if (args.includes("--help") || args.includes("-h")) {
      console.log(HELP);
      Deno.exit(0);
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
          console.log(HELP);
          Deno.exit(1);
        }
        flagKey = nxt;
        i++;
      } else if (arg.startsWith("--api-key=")) {
        const val = arg.slice("--api-key=".length);
        if (!val) {
          console.error("ERROR: --api-key requires a value");
          console.log(HELP);
          Deno.exit(1);
        }
        flagKey = val;
      } else if (arg.startsWith("-")) {
        console.error(`ERROR: unknown flag "${arg}"`);
        console.log(HELP);
        Deno.exit(1);
      } else {
        console.error(`ERROR: unknown argument "${arg}"`);
        console.log(HELP);
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
