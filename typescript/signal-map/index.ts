// Function to print to stderr in red
function logError(message: string): never {
  process.stderr.write("\x1b[31m[ERROR]\x1b[0m");
  process.stderr.write(` ${message}\n`);
  process.exit(1);
}

function signalExitCode(num: number): number | null {
  // Convention: exit code = 128 + signal number (if <= 31)
  if (num > 0 && num <= 31) return 128 + num;
  return null;
}

async function getSignalMap(): Promise<Map<string, number>> {
  const command = Bun.spawn({
    cmd: ["bash", "-c", "trap -l"],
    stdout: "pipe",
    stderr: "pipe",
  });

  const stdout = (await command.stdout.text()).trim();
  const stderr = (await command.stderr.text()).trim();
  const code = command.exitCode;

  if (code !== 0) {
    // Combine stderr and stdout for better error context if stderr is empty
    const errorOutput = stderr ?? stdout ?? "No output";
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

async function main() {
  try {
    const argv = process.argv.slice(2);
    const argc = process.argv.length - 2;
    const signals = await getSignalMap();

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

    if ((error as any).code === "ENOENT") {
      errorMessage = "Command not found";
    } else if (Error.isError(error)) {
      errorMessage = error.message;
    } else if (typeof error === "string") {
      errorMessage = error;
    }

    logError(`Failed to execute command: ${errorMessage}`);
  }
}

if (import.meta.main) await main();
