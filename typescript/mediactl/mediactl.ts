#!/usr/bin/env -S deno run -A
import type { MessageBus } from "dbus-next";
import { sessionBus, Variant, Message, MessageType } from "dbus-next";

const MAX_TRACK_LENGTH = 35;
const DEBUG = Deno.env.get("DEBUG") === "1";

interface Metadata {
  "xesam:artist"?: string[];
  "xesam:title"?: string;
  "xesam:album"?: string;
  "xesam:trackNumber"?: number;
}

interface PlayerState {
  busName: string;
  playbackStatus: "Playing" | "Paused" | "Stopped";
  metadata: Metadata;
}

const players = new Map<string, PlayerState>();
let pollInterval: number | null = null;

function callDbusMethod(
  bus: MessageBus,
  destination: string,
  path: string,
  interfaceName: string,
  methodName: string,
  signature: string,
  body: unknown[]
): Promise<Message | null> {
  const msg = new Message({
    type: MessageType.METHOD_CALL,
    destination,
    path,
    interface: interfaceName,
    member: methodName,
    signature,
    body,
  });
  return bus.call(msg);
}

function formatTrackInfo(metadata: Metadata): string {
  const artistVariant = metadata["xesam:artist"] as unknown;
  const titleVariant = metadata["xesam:title"] as unknown;

  let artist = "Unknown Artist";
  let title = "Unknown Title";

  if (
    artistVariant &&
    typeof artistVariant === "object" &&
    "value" in artistVariant &&
    Array.isArray((artistVariant as { value: string[] }).value) &&
    (artistVariant as { value: string[] }).value.length > 0
  ) {
    artist = String((artistVariant as { value: string[] }).value[0]);
  }

  if (
    titleVariant &&
    typeof titleVariant === "object" &&
    "value" in titleVariant
  ) {
    title = String((titleVariant as { value: string }).value);
  }

  const track = `${artist} - ${title}`;

  if (DEBUG) {
    console.log(`[DEBUG] Format track: "${track}" (${track.length} chars)`);
  }

  if (track.length <= MAX_TRACK_LENGTH) {
    return track;
  }

  return `${track.substring(0, MAX_TRACK_LENGTH - 3)}...`;
}

function sendPolybarMessage(module: string, hook: number, content?: string): void {
  if (DEBUG) {
    console.log(
      `[DEBUG] Sending polybar message: #${module}.${hook}${content ? ` "${content}"` : ""}`
    );
  }
  const args = content
    ? ["action", `#${module}.${hook}`, content]
    : ["action", `#${module}.${hook}`];

  const command = new Deno.Command("polybar-msg", {
    args,
    stdout: "null",
    stderr: "null",
  });

  command.spawn();
  if (DEBUG) {
    Deno.stdout.writeSync(new TextEncoder().encode("\n"));
  }
}

function updateMediaHook(): void {
  const activePlayers = Array.from(players.values()).filter(
    p => p.playbackStatus !== "Stopped"
  );

  if (DEBUG) {
    console.log(
      `[DEBUG] Total players: ${players.size}, Active: ${activePlayers.length}`
    );
  }

  if (activePlayers.length === 0) {
    sendPolybarMessage("media", 0);
    sendPolybarMessage("playpause", 0);
    sendPolybarMessage("previous", 0);
    sendPolybarMessage("next", 0);
    if (DEBUG) {
      console.log("[DEBUG] No active players - hiding all controls");
    }
    stopPolling();
    return;
  }

  const player = activePlayers[0];
  const trackInfo = formatTrackInfo(player.metadata);
  sendPolybarMessage("media", 1, trackInfo);

  const playpauseState = player.playbackStatus === "Playing" ? 1 : 2;
  sendPolybarMessage("playpause", playpauseState);
  sendPolybarMessage("previous", 1);
  sendPolybarMessage("next", 1);

  if (DEBUG) {
    console.log(`[DEBUG] Active player: ${player.busName}`);
    console.log(`[DEBUG] Status: ${player.playbackStatus}`);
    console.log(`[DEBUG] Track: ${trackInfo}`);
  }
}

function isMPRISPlayer(busName: string): boolean {
  return busName.startsWith("org.mpris.MediaPlayer2.");
}

async function handlePlayerAdded(
  bus: MessageBus,
  busName: string
): Promise<void> {
  if (!isMPRISPlayer(busName)) {
    return;
  }

  if (players.has(busName)) {
    return;
  }

  if (DEBUG) {
    console.log(`[DEBUG] Player added: ${busName}`);
  }

  try {
    let proxy:
      | Awaited<ReturnType<MessageBus["getProxyObject"]>>
      | undefined;

    try {
      proxy = await bus.getProxyObject(busName, "/org/mpris/MediaPlayer2");
    } catch (_introspectionError) {
      if (DEBUG) {
        console.log(
          `[DEBUG] Introspection failed for ${busName}, trying direct DBus calls`
        );
      }
    }

    let propertiesInterface: unknown;

    if (proxy && Object.keys(proxy.interfaces).includes("org.freedesktop.DBus.Properties")) {
      propertiesInterface = proxy.getInterface("org.freedesktop.DBus.Properties");
    }

    let metadata: Metadata;
    let playbackStatus: string;

    if (propertiesInterface) {
      // @ts-ignore - dbus-next types are incomplete
      metadata = (await propertiesInterface.Get(
        "org.mpris.MediaPlayer2.Player",
        "Metadata"
      )).value as Metadata;
      // @ts-ignore - dbus-next types are incomplete
      playbackStatus = (await propertiesInterface.Get(
        "org.mpris.MediaPlayer2.Player",
        "PlaybackStatus"
      )).value as string;
    } else {
      const metadataMsg = await callDbusMethod(
        bus,
        busName,
        "/org/mpris/MediaPlayer2",
        "org.freedesktop.DBus.Properties",
        "Get",
        "ss",
        ["org.mpris.MediaPlayer2.Player", "Metadata"]
      );

      const statusMsg = await callDbusMethod(
        bus,
        busName,
        "/org/mpris/MediaPlayer2",
        "org.freedesktop.DBus.Properties",
        "Get",
        "ss",
        ["org.mpris.MediaPlayer2.Player", "PlaybackStatus"]
      );

      if (!metadataMsg || !statusMsg) {
        throw new Error("Failed to get player properties");
      }

      metadata = (metadataMsg.body![0] as Variant<Metadata>).value;
      playbackStatus = (statusMsg.body![0] as Variant<string>).value;
    }

    players.set(busName, {
      busName,
      playbackStatus: playbackStatus as "Playing" | "Paused" | "Stopped",
      metadata,
    });

    // Ensure polling is active
    startPolling(bus);

    if (DEBUG) {
      console.log(
        `[DEBUG] Player ${busName} initialized - Status: ${playbackStatus}`
      );
    }

    updateMediaHook();
  } catch (error) {
    console.error(`Error connecting to ${busName}:`, error);
  }
}

function handlePlayerRemoved(busName: string): void {
  if (!isMPRISPlayer(busName)) {
    return;
  }

  if (players.delete(busName)) {
    if (DEBUG) {
      console.log(`[DEBUG] Player removed: ${busName}`);
    }
    updateMediaHook();
  }
}

async function listActivePlayers(bus: MessageBus): Promise<void> {
  try {
    const proxy = await bus.getProxyObject(
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus"
    );
    const dbusInterface = proxy.getInterface("org.freedesktop.DBus");

    const names = (await dbusInterface.ListNames()) as string[];
    const mprisNames = names.filter(isMPRISPlayer);

    if (DEBUG) {
      console.log(
        `[DEBUG] Found ${mprisNames.length} MPRIS players: ${mprisNames.join(", ")}`
      );
    }

    for (const name of names) {
      await handlePlayerAdded(bus, name);
    }
  } catch (error) {
    console.error("Error listing active players:", error);
  }
}

function main(): void {
  console.log("Starting MPRIS Media Control for Polybar...");
  if (DEBUG) {
    console.log("[DEBUG] Debug mode enabled");
  }

  const bus = sessionBus();

  bus.on("connect", async () => {
    console.log("Connected to DBus session bus");

    // Add match rules to receive signals
    try {
      await bus.call(
        new Message({
          type: MessageType.METHOD_CALL,
          destination: "org.freedesktop.DBus",
          path: "/org/freedesktop/DBus",
          interface: "org.freedesktop.DBus",
          member: "AddMatch",
          signature: "s",
          body: ["type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/mpris/MediaPlayer2'"],
        })
      );
      await bus.call(
        new Message({
          type: MessageType.METHOD_CALL,
          destination: "org.freedesktop.DBus",
          path: "/org/freedesktop/DBus",
          interface: "org.freedesktop.DBus",
          member: "AddMatch",
          signature: "s",
          body: ["type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"],
        })
      );
      if (DEBUG) {
        console.log("[DEBUG] Added DBus match rules for signals");
      }
    } catch (e) {
      if (DEBUG) {
        console.log(`[DEBUG] Failed to add match rules: ${e}`);
      }
    }

    await listActivePlayers(bus);

    // Start polling as a fallback for when signals don't work
    startPolling(bus);
  });

  bus.on("message", async (msg: Message) => {
    if (DEBUG) {
      console.log(
        `[DEBUG] Raw message: type=${msg.type}, iface=${msg.interface}, member=${msg.member}, sender=${msg.sender}, path=${msg.path}`
      );
    }

    // Handle NameOwnerChanged signals for player appearance/disappearance
    if (
      msg.interface === "org.freedesktop.DBus" &&
      msg.member === "NameOwnerChanged"
    ) {
      const [name, oldOwner, newOwner] = msg.body as [string, string, string];

      if (isMPRISPlayer(name) && DEBUG) {
        console.log(
          `[DEBUG] NameOwnerChanged: ${name} (old: ${oldOwner ? "yes" : "no"}, new: ${newOwner ? "yes" : "no"})`
        );
      }

      if (newOwner && !oldOwner) {
        await handlePlayerAdded(bus, name);
      } else if (!newOwner && oldOwner) {
        handlePlayerRemoved(name);
        if (players.size === 0) {
          stopPolling();
        }
      }
    }

    // Try to handle PropertiesChanged signals even if iface/member are undefined
    if (msg.type === MessageType.SIGNAL && msg.path === "/org/mpris/MediaPlayer2") {
      if (DEBUG) {
        console.log(`[DEBUG] Signal from ${msg.sender} with body:`, msg.body);
      }

      // Try to parse as PropertiesChanged
      if (msg.body && Array.isArray(msg.body) && msg.body.length >= 2) {
        const [iface, changed] = msg.body as [string, Record<string, Variant<unknown>>];

        if (DEBUG) {
          console.log(`[DEBUG] Parsed signal: iface=${iface}, changes=${Object.keys(changed).length}`);
        }

        if (iface === "org.mpris.MediaPlayer2.Player" && msg.sender && players.has(msg.sender)) {
          const state = players.get(msg.sender);
          if (!state) return;

          let hasChanges = false;

          if (changed.Metadata) {
            state.metadata = changed.Metadata.value as Metadata;
            hasChanges = true;
            if (DEBUG) {
              console.log(`[DEBUG] ${msg.sender}: Metadata changed via signal`);
            }
          }
          if (changed.PlaybackStatus) {
            state.playbackStatus = changed.PlaybackStatus.value as "Playing" | "Paused" | "Stopped";
            hasChanges = true;
            if (DEBUG) {
              console.log(`[DEBUG] ${msg.sender}: PlaybackStatus -> ${state.playbackStatus} via signal`);
            }
          }

          if (hasChanges) {
            updateMediaHook();
          }
        }
      }
    }

    // Also try the standard way for completeness
    if (
      msg.interface === "org.freedesktop.DBus.Properties" &&
      msg.member === "PropertiesChanged" &&
      msg.path === "/org/mpris/MediaPlayer2"
    ) {
      const [iface, changed, _invalidated] = msg.body as [
        string,
        Record<string, Variant<unknown>>,
        string[]
      ];

      if (DEBUG) {
        console.log(`[DEBUG] PropertiesChanged from ${msg.sender}: ${iface} with ${Object.keys(changed).length} changes`);
        for (const [key, variant] of Object.entries(changed)) {
          console.log(`[DEBUG]   ${key}: ${JSON.stringify((variant as Variant<unknown>).value)}`);
        }
      }

      if (msg.sender && players.has(msg.sender) && iface === "org.mpris.MediaPlayer2.Player") {
        const state = players.get(msg.sender);
        if (!state) return;

        if (changed.Metadata) {
          state.metadata = changed.Metadata.value as Metadata;
          if (DEBUG) {
            console.log(`[DEBUG] ${msg.sender}: Metadata changed`);
          }
        }
        if (changed.PlaybackStatus) {
          state.playbackStatus = changed.PlaybackStatus.value as "Playing" | "Paused" | "Stopped";
          if (DEBUG) {
            console.log(`[DEBUG] ${msg.sender}: PlaybackStatus -> ${state.playbackStatus}`);
          }
        }

        updateMediaHook();
      }
    }
  });

  bus.on("error", (error: Error) => {
    console.error("DBus error:", error);
  });
}

// Keep process alive to continue receiving DBus signals
function keepAlive(): Promise<never> {
  return new Promise<never>(() => {
    // This promise never resolves, keeping the process running
  });
}

// Force refresh every 5 seconds as a fallback
async function forceRefresh(bus: MessageBus): Promise<void> {
  if (DEBUG) {
    console.log("[DEBUG] Forced refresh of all players");
  }
  await listActivePlayers(bus);
}

async function pollPlayerState(bus: MessageBus): Promise<void> {
  if (DEBUG) {
    console.log(`[DEBUG] Poll: checking ${players.size} players...`);
  }

  for (const [busName, state] of players) {
    try {
      const proxy = await bus.getProxyObject(busName, "/org/mpris/MediaPlayer2");
      const propertiesInterface = proxy.getInterface("org.freedesktop.DBus.Properties");

      const newMetadata = (await propertiesInterface.Get(
        "org.mpris.MediaPlayer2.Player",
        "Metadata"
      )) as { value: Metadata };
      const newPlaybackStatus = (await propertiesInterface.Get(
        "org.mpris.MediaPlayer2.Player",
        "PlaybackStatus"
      )) as { value: string };

      let changed = false;

      const metadataChanged = JSON.stringify(newMetadata.value) !== JSON.stringify(state.metadata);
      const statusChanged = newPlaybackStatus.value !== state.playbackStatus;

      if (DEBUG) {
        console.log(`[DEBUG] Poll: ${busName} - status=${newPlaybackStatus.value}, metadata_changed=${metadataChanged}, status_changed=${statusChanged}`);
        console.log(`[DEBUG] Poll: ${busName} - current status=${state.playbackStatus}`);
        console.log(`[DEBUG] Poll: ${busName} - current metadata keys=${Object.keys(state.metadata).join(',')}`);
        console.log(`[DEBUG] Poll: ${busName} - new metadata keys=${Object.keys(newMetadata.value).join(',')}`);
      }

      if (metadataChanged) {
        state.metadata = newMetadata.value;
        changed = true;
        if (DEBUG) {
          console.log(`[DEBUG] Poll: ${busName} metadata changed`);
        }
      }

      if (statusChanged) {
        state.playbackStatus = newPlaybackStatus.value as "Playing" | "Paused" | "Stopped";
        changed = true;
        if (DEBUG) {
          console.log(`[DEBUG] Poll: ${busName} status -> ${state.playbackStatus}`);
        }
      }

      if (changed) {
        updateMediaHook();
      }
    } catch (_e) {
      // Player might have closed, ignore errors
    }
  }
}

function startPolling(bus: MessageBus): void {
  if (pollInterval !== null) return;

  if (DEBUG) {
    console.log("[DEBUG] Starting poll-based state monitoring (fallback)");
  }

  pollInterval = setInterval(() => {
    pollPlayerState(bus);
  }, 1000) as unknown as number;
}

function stopPolling(): void {
  if (pollInterval !== null) {
    clearInterval(pollInterval);
    pollInterval = null;
    if (DEBUG) {
      console.log("[DEBUG] Stopping poll-based state monitoring");
    }
  }
}

async function run(): Promise<void> {
  main();
  await keepAlive();
}

if (import.meta.main) {
  run().catch(console.error);
}
