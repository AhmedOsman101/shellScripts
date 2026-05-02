#!/usr/bin/env -S deno run --allow-env --allow-net

// featherless - CLI tool to query the Featherless AI API
//
// Usage:
//   featherless <prompt>              # Use default model
//   featherless "your question" -m Qwen/Qwen3.5-397B-A17B
//   featherless "explain OOP" --model openai/gpt-oss-120b -q
//
// Options:
//   -m, --model <name>  Model to use (interactive selection if omitted)
//   -q, --quiet         Hide reasoning and section headers
//

import process from "node:process";
import { createInterface } from "node:readline";

// --- Types ---

type Role = "system" | "user" | "assistant" | "tool";

type FinishReason = "stop" | "length" | "content_filter" | "tool_calls";

interface RequestMessage {
  role: Role;
  content: string;
}

interface Usage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface StreamDelta {
  role?: "assistant";
  reasoning?: string;
  content?: string;
}

interface StreamChoice {
  index: number;
  delta: StreamDelta;
  finish_reason: FinishReason | null;
}

interface StreamChunk {
  id: string;
  object: "chat.completion.chunk";
  created: number;
  model: string;
  choices: StreamChoice[];
  system_fingerprint?: string;
  usage?: Usage;
}

interface ApiError {
  error: {
    message: string;
    type: string;
    param: string | null;
    code: string | null;
  };
}

const MODEL_LIST = [
  "openai/gpt-oss-120b",
  "Qwen/Qwen3-Coder-480B-A35B-Instruct",
  "deepseek-ai/DeepSeek-V4-Pro",
  "zai-org/GLM-5.1",
  "moonshotai/Kimi-K2.6",
  "Qwen/Qwen3-Coder-Next",
  "deepseek-ai/DeepSeek-V3.2",
  "Qwen/Qwen3.5-397B-A17B"
] as const;

// deno-lint-ignore ban-types
type Model = (typeof MODEL_LIST)[keyof typeof MODEL_LIST] | (string & {});

interface RequestOptions {
  model: Model;
  messages: RequestMessage[];
  temperature?: number;
  top_p?: number;
  max_tokens?: number;
  stream?: boolean;
}

// --- Helpers ---

const encoder = new TextEncoder();
const decoder = new TextDecoder();

interface CliFlags {
  model?: string;
  quiet: boolean;
  prompt?: string;
}

function parseArgs(args: string[]): CliFlags {
  const flags: CliFlags = { quiet: false };
  let i = 0;
  while (i < args.length) {
    if (args[i] === "--model" || args[i] === "-m") {
      flags.model = args[++i];
    } else if (args[i] === "--quiet" || args[i] === "-q") {
      flags.quiet = true;
    } else if (!flags.prompt) {
      flags.prompt = args[i];
    }
    i++;
  }
  return flags;
}

async function selectModel(): Promise<Model> {
  console.log("Select a model:\n");
  for (let i = 0; i < MODEL_LIST.length; i++) {
    console.log(`  ${String(i + 1).padStart(2)}) ${MODEL_LIST[i]}`);
  }
  console.log("");

  const answer = await readInput("Enter number or custom model name: ");
  const num = Number.parseInt(answer, 10);
  if (num >= 1 && num <= MODEL_LIST.length) {
    return MODEL_LIST[num - 1];
  }
  return answer.trim() || MODEL_LIST[0];
}

async function readInput(prompt: string): Promise<string> {
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const answer = await new Promise<string>(resolve => {
    rl.question(prompt, resolve);
  });

  rl.close();
  return answer;
}

function logError(message: string): never {
  console.error(`\x1b[31m${message}\x1b[0m`);
  Deno.exit(1);
}

function buildHeaders(apiKey: string): Record<string, string> {
  return {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
    "HTTP-Referer": "http://localhost",
    "X-Title": `Chat with featherless ${Date.now()}`,
  };
}

function buildBody(options: RequestOptions): string {
  return JSON.stringify({
    ...options,
    temperature: options.temperature ?? 0.7,
    stream: options.stream ?? false,
  });
}

async function streamResponse(
  response: Response,
  quiet: boolean
): Promise<void> {
  const reader = response.body?.getReader();
  if (!reader) {
    logError("Response body is not readable as stream");
  }

  let buffer = "";
  let outBuffer = "";
  let inReasoning = false;
  const skipReasoning = quiet;

  const flushTimer = setInterval(() => {
    if (outBuffer.length > 0) {
      Deno.stdout.writeSync(encoder.encode(outBuffer));
      outBuffer = "";
    }
  }, 32);

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });

      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || !trimmed.startsWith("data: ")) continue;

        const data = trimmed.slice(6);
        if (data === "[DONE]") break;

        try {
          const chunk: StreamChunk = JSON.parse(data);
          const delta = chunk.choices[0]?.delta;

          if (delta?.reasoning) {
            if (skipReasoning) continue;
            if (!inReasoning) {
              outBuffer += "\n--- Reasoning ---\n";
              inReasoning = true;
            }
            outBuffer += delta.reasoning;
          }
          if (delta?.content) {
            if (inReasoning) {
              outBuffer += "\n\n--- Response ---\n\n";
              inReasoning = false;
            }
            outBuffer += delta.content;
          }
        } catch {
          // Skip malformed chunks
        }
      }
    }
  } finally {
    clearInterval(flushTimer);
    if (outBuffer.length > 0) {
      Deno.stdout.writeSync(encoder.encode(outBuffer));
    }
  }
}

// --- Main ---

const SYSTEM_PROMPT = `You are an expert-level software engineer and technical assistant.

Your primary goal is to provide precise, correct, and production-quality answers with a strong focus on software engineering best practices.

General behavior:
- Be direct and efficient. Avoid unnecessary verbosity.
- Do not simplify unless explicitly asked.
- Assume the user has solid programming knowledge.
- Avoid filler, motivational language, or hand-holding.

Technical standards:
- Always prioritize correctness, performance, and maintainability.
- Follow modern best practices and idiomatic patterns for the given language.
- Prefer explicitness over implicit behavior.
- Highlight edge cases, trade-offs, and potential pitfalls.
- When multiple approaches exist, compare them with pros/cons.

Code generation:
- Produce clean, readable, and production-ready code.
- Follow consistent formatting and naming conventions.
- Avoid anti-patterns and legacy practices.
- Include type safety where applicable (especially in TypeScript).
- Minimize dependencies unless justified.
- Optimize for clarity first, then performance (unless performance is critical).

Explanations:
- Focus on "why" and "how", not just "what".
- Use concise, structured reasoning.
- Avoid repeating obvious information.
- When relevant, explain internal mechanics (e.g., runtime behavior, memory, complexity).

Debugging & problem solving:
- Identify root causes, not just symptoms.
- Provide systematic debugging steps.
- Point out assumptions explicitly.
- Consider environment-specific issues (runtime, OS, tooling).

Advanced guidance:
- Suggest better architectural approaches when appropriate.
- Call out design flaws or scalability concerns.
- Provide alternatives if the user's approach is suboptimal.

Constraints:
- Do not hallucinate APIs or behavior.
- If unsure, clearly state uncertainty.
- Do not over-explain basic concepts unless asked.

Tone:
- Professional, concise, and technically dense.
- No emojis, no casual tone.`;

async function main() {
  const flags = parseArgs(Deno.args);
  const userPrompt = flags.prompt || (await readInput("Enter your prompt: "));

  if (!userPrompt.trim()) {
    logError("Error: No prompt provided. Usage: featherless <prompt>");
  }

  const apiKey = Deno.env.get("FEATHERLESS_API_KEY");
  if (!apiKey) {
    logError("Missing FEATHERLESS_API_KEY environment variable");
  }

  let selectedModel: Model = flags.model ?? "";
  if (!selectedModel) {
    selectedModel = await selectModel();
  }

  const requestOptions: RequestOptions = {
    model: selectedModel,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: userPrompt },
    ],
    stream: true,
  };

  const response = await fetch(
    "https://api.featherless.ai/v1/chat/completions",
    {
      method: "POST",
      headers: buildHeaders(apiKey),
      body: buildBody(requestOptions),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    let errorMessage = errorText;
    try {
      const errorJson: ApiError = JSON.parse(errorText);
      errorMessage = errorJson.error.message;
    } catch {
      // Use raw error text if not JSON
    }
    logError(`API error (${response.status}): ${errorMessage}`);
  }

  await streamResponse(response, flags.quiet);
  Deno.stdout.writeSync(encoder.encode("\n"));
}

if (import.meta.main) main();
