#!/usr/bin/env -S deno run --allow-env --allow-net

import process from "node:process";
import { createInterface } from "node:readline";

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
  console.error(`\x1b[31m${message}\x1b[0m`);
  Deno.exit(1);
}

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
- Provide alternatives if the user’s approach is suboptimal.

Constraints:
- Do not hallucinate APIs or behavior.
- If unsure, clearly state uncertainty.
- Do not over-explain basic concepts unless asked.

Tone:
- Professional, concise, and technically dense.
- No emojis, no casual tone.`;

async function main() {
  // Get command-line arguments
  const prompt = Deno.args.at(0) || (await input("Enter your prompt: "));

  if (!prompt.trim())
    logError("Error: No prompt provided. Usage: featherless <prompt>");

  // Read API key from environment
  const apiKey = Deno.env.get("FEATHERLESS_API_KEY");
  if (!apiKey) {
    logError("Missing FEATHERLESS_API_KEY environment variable");
  }

  const headers = {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
    "HTTP-Referer": "http://localhost",
    "X-Title": `Chat with featherless ${Date.now()}`,
  };

  const body = {
    // model: "openai/gpt-oss-120b",
    model: "Qwen/Qwen3.5-397B-A17B",
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      {
        role: "user",
        content: prompt,
      },
    ],
    temperature: 0.7,
    // top_p: 0.9,
    // max_tokens: 300,
  };

  const response = await fetch(
    "https://api.featherless.ai/v1/chat/completions",
    {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    logError(
      `API error (${response.status}) ${response.statusText}: ${errorText}`
    );
  }

  const data = await response.json();
  console.dir(data, { depth: Number.POSITIVE_INFINITY });
  // console.log(data.choices[0].message.content);
  // console.log(data.usage);
}

if (import.meta.main) main();
