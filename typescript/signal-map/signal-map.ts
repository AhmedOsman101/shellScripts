#!/usr/bin/env -S deno run --allow-run

// Function to print to stderr in red
function logError(message: string): never {
  console.error(`\x1b[31m${message}\x1b[0m`);
  Deno.exit(1);
}

function signalExitCode(num: number): number | null {
  // Convention: exit code = 128 + signal number (if <= 31)
  if (num > 0 && num <= 31) return 128 + num;
  return null;
}

function getSignalMap(): Map<string, number> {
  const command = new Deno.Command("bash", {
    args: ["-c", "trap -l"],
  });

  const output = command.outputSync();

  const decoder = new TextDecoder();

  const stdout = decoder.decode(output.stdout).trim();
  const stderr = decoder.decode(output.stderr).trim();
  const code = output.code;

  if (code !== 0) {
    // Combine stderr and stdout for better error context if stderr is empty
    const errorOutput = stderr || stdout || "No output";
    logError(`Command failed with code ${code}: ${errorOutput}`);
  }

  const map = new Map<string, number>();
  stdout
    .replaceAll("\t", "\n")
    .split("\n")
    .forEach(s => {
      const pair = s.trim().split(") ");
      map.set(pair[1], Number(pair[0]));
    });
  return map;
}

function main() {
  try {
    const argv = Deno.args;
    const argc = Deno.args.length;
    const signals = getSignalMap();

    switch (argc) {
      case 0:
        console.dir(signals);
        return;
      case 1:
        break;
      default:
        logError("Usage: signal-map <signal-number|signal-name>");
    }

    const input = argv[0];
    if (/^\d+$/.test(input)) {
      const num = Number(input);
      const signal = signals.entries().find(v => v[1] === num);
      if (!signal) logError(`Unknown signal number: ${num}`);
      const [name, number] = signal;

      const code = signalExitCode(number);
      console.log(`${number} ${name}${code !== null ? ` ${code}` : " "}`);
    } else {
      const name = input.toUpperCase().startsWith("SIG")
        ? input.toUpperCase()
        : `SIG${input.toUpperCase()}`;
      const signal = signals.get(name);
      if (!signal) logError(`Unknown signal name: ${input}`);

      const code = signalExitCode(signal);
      console.log(`${signal} ${name}${code !== null ? ` ${code}` : " "}`);
    }
  } catch (error) {
    let errorMessage = "An unknown error occurred";

    if (error instanceof Deno.errors.NotFound) {
      errorMessage = "Command not found";
    } else if (error instanceof Deno.errors.PermissionDenied) {
      errorMessage = "Permission denied";
    } else if (error instanceof Error) {
      errorMessage = error.message;
    } else if (typeof error === "string") {
      errorMessage = error;
    }

    logError(`Failed to execute command: ${errorMessage}`);
  }
}

if (import.meta.main) main();
