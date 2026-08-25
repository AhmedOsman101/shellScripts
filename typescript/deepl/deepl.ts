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

if (Deno.args.includes("--help") || Deno.args.includes("-h") || Deno.args.length === 0) {
  console.log(HELP);
  Deno.exit(0);
}
console.log(HELP);
