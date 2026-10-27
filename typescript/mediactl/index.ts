import type { MessageBus } from "dbus-next";
import { Message, MessageType, sessionBus, type Variant } from "dbus-next";

const MAX_TRACK_LENGTH = 35;
const DEBUG = process.env.DEBUG === "1";

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

function logDebug(...data: any[]) {
  if (DEBUG) {
    console.debug("[DEBUG]", ...data);
  }
}

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

  logDebug(`Format track: "${track}" (${track.length} chars)`);

  if (track.length <= MAX_TRACK_LENGTH) {
    return track;
  }

  return `${track.substring(0, MAX_TRACK_LENGTH - 3)}...`;
}

function sendPolybarMessage(
  module: string,
  hook: number,
  content?: string
): void {
  logDebug(
    `Sending polybar message: #${module}.${hook}${content ? ` "${content}"` : ""}`
  );
  const args = content
    ? ["action", `#${module}.${hook}`, content]
    : ["action", `#${module}.${hook}`];

  const command = Bun.spawn({
    cmd: ["polybar-msg", ...args],
    stdout: null,
    stderr: null,
  });

  command.exitCode;
  if (DEBUG) {
    process.stdout.write("\n");
  }
}

function updateMediaHook(): void {
  const activePlayers = Array.from(players.values()).filter(
    p => p.playbackStatus !== "Stopped"
  );

  logDebug(`Total players: ${players.size}, Active: ${activePlayers.length}`);

  if (activePlayers.length === 0) {
    sendPolybarMessage("media", 0);
    sendPolybarMessage("playpause", 0);
    sendPolybarMessage("previous", 0);
    sendPolybarMessage("next", 0);

    logDebug("No active players - hiding all controls");

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

  logDebug(`Active player: ${player.busName}`);
  logDebug(`Status: ${player.playbackStatus}`);
  logDebug(`Track: ${trackInfo}`);
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

  logDebug(`Player added: ${busName}`);

  try {
    let proxy: Awaited<ReturnType<MessageBus["getProxyObject"]>> | undefined;

    try {
      proxy = await bus.getProxyObject(busName, "/org/mpris/MediaPlayer2");
    } catch (_introspectionError) {
      logDebug(`Introspection failed for ${busName}, trying direct DBus calls`);
    }

    let propertiesInterface: unknown;

    if (
      proxy &&
      Object.keys(proxy.interfaces).includes("org.freedesktop.DBus.Properties")
    ) {
      propertiesInterface = proxy.getInterface(
        "org.freedesktop.DBus.Properties"
      );
    }

    let metadata: Metadata;
    let playbackStatus: string;

    if (propertiesInterface) {
      metadata =
        (
        // @ts-expect-error - dbus-next types are incomplete
          await propertiesInterface.Get(
            "org.mpris.MediaPlayer2.Player",
            "Metadata"
          )
        ).value as Metadata;
      playbackStatus =
        (
          // @ts-expect-error - dbus-next types are incomplete
          await propertiesInterface.Get(
            "org.mpris.MediaPlayer2.Player",
            "PlaybackStatus"
          )
        ).value as string;
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

    logDebug(`Player ${busName} initialized - Status: ${playbackStatus}`);

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
    logDebug(`Player removed: ${busName}`);
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

    logDebug(
      `Found ${mprisNames.length} MPRIS players: ${mprisNames.join(", ")}`
    );

    for (const name of names) {
      await handlePlayerAdded(bus, name);
    }
  } catch (error) {
    console.error("Error listing active players:", error);
  }
}

function main(): void {
  console.log("Starting MPRIS Media Control for Polybar...");
  logDebug("Debug mode enabled");

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
          body: [
            "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/mpris/MediaPlayer2'",
          ],
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
          body: [
            "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'",
          ],
        })
      );
      logDebug("Added DBus match rules for signals");
    } catch (e) {
      logDebug(`Failed to add match rules: ${e}`);
    }

    await listActivePlayers(bus);

    // Start polling as a fallback for when signals don't work
    startPolling(bus);
  });

  bus.on("message", async (msg: Message) => {
    logDebug(
      `Raw message: type=${msg.type}, iface=${msg.interface}, member=${msg.member}, sender=${msg.sender}, path=${msg.path}`
    );

    // Handle NameOwnerChanged signals for player appearance/disappearance
    if (
      msg.interface === "org.freedesktop.DBus" &&
      msg.member === "NameOwnerChanged"
    ) {
      const [name, oldOwner, newOwner] = msg.body as [string, string, string];

      if (isMPRISPlayer(name)) {
        logDebug(
          `NameOwnerChanged: ${name} (old: ${oldOwner ? "yes" : "no"}, new: ${newOwner ? "yes" : "no"})`
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
    if (
      msg.type === MessageType.SIGNAL &&
      msg.path === "/org/mpris/MediaPlayer2"
    ) {
      logDebug(`Signal from ${msg.sender} with body:`, msg.body);

      // Try to parse as PropertiesChanged
      if (msg.body && Array.isArray(msg.body) && msg.body.length >= 2) {
        const [iface, changed] = msg.body as [
          string,
          Record<string, Variant<unknown>>,
        ];

        logDebug(
          `Parsed signal: iface=${iface}, changes=${Object.keys(changed).length}`
        );

        if (
          iface === "org.mpris.MediaPlayer2.Player" &&
          msg.sender &&
          players.has(msg.sender)
        ) {
          const state = players.get(msg.sender);
          if (!state) return;

          let hasChanges = false;

          if (changed.Metadata) {
            state.metadata = changed.Metadata.value as Metadata;
            hasChanges = true;
            logDebug(`${msg.sender}: Metadata changed via signal`);
          }
          if (changed.PlaybackStatus) {
            state.playbackStatus = changed.PlaybackStatus.value as
              | "Playing"
              | "Paused"
              | "Stopped";
            hasChanges = true;
            logDebug(
              `${msg.sender}: PlaybackStatus -> ${state.playbackStatus} via signal`
            );
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
        string[],
      ];

      if (DEBUG) {
        logDebug(
          `PropertiesChanged from ${msg.sender}: ${iface} with ${Object.keys(changed).length} changes`
        );
        for (const [key, variant] of Object.entries(changed)) {
          logDebug(
            `  ${key}: ${JSON.stringify((variant as Variant<unknown>).value)}`
          );
        }
      }

      if (
        msg.sender &&
        players.has(msg.sender) &&
        iface === "org.mpris.MediaPlayer2.Player"
      ) {
        const state = players.get(msg.sender);
        if (!state) return;

        if (changed.Metadata) {
          state.metadata = changed.Metadata.value as Metadata;
          logDebug(`${msg.sender}: Metadata changed`);
        }
        if (changed.PlaybackStatus) {
          state.playbackStatus = changed.PlaybackStatus.value as
            | "Playing"
            | "Paused"
            | "Stopped";
          logDebug(`${msg.sender}: PlaybackStatus -> ${state.playbackStatus}`);
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
  logDebug("Forced refresh of all players");
  await listActivePlayers(bus);
}

async function pollPlayerState(bus: MessageBus): Promise<void> {
  logDebug(`Poll: checking ${players.size} players...`);

  for (const [busName, state] of players) {
    try {
      const proxy = await bus.getProxyObject(
        busName,
        "/org/mpris/MediaPlayer2"
      );
      const propertiesInterface = proxy.getInterface(
        "org.freedesktop.DBus.Properties"
      );

      const newMetadata = (await propertiesInterface.Get(
        "org.mpris.MediaPlayer2.Player",
        "Metadata"
      )) as { value: Metadata };
      const newPlaybackStatus = (await propertiesInterface.Get(
        "org.mpris.MediaPlayer2.Player",
        "PlaybackStatus"
      )) as { value: string };

      let changed = false;

      const metadataChanged =
        JSON.stringify(newMetadata.value) !== JSON.stringify(state.metadata);
      const statusChanged = newPlaybackStatus.value !== state.playbackStatus;

      logDebug(
        `Poll: ${busName} - status=${newPlaybackStatus.value}, metadata_changed=${metadataChanged}, status_changed=${statusChanged}`
      );
      logDebug(`Poll: ${busName} - current status=${state.playbackStatus}`);
      logDebug(
        `Poll: ${busName} - current metadata keys=${Object.keys(state.metadata).join(",")}`
      );
      logDebug(
        `Poll: ${busName} - new metadata keys=${Object.keys(newMetadata.value).join(",")}`
      );

      if (metadataChanged) {
        state.metadata = newMetadata.value;
        changed = true;
        logDebug(`Poll: ${busName} metadata changed`);
      }

      if (statusChanged) {
        state.playbackStatus = newPlaybackStatus.value as
          | "Playing"
          | "Paused"
          | "Stopped";
        changed = true;
        logDebug(`Poll: ${busName} status -> ${state.playbackStatus}`);
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

  logDebug("Starting poll-based state monitoring (fallback)");

  pollInterval = setInterval(() => {
    pollPlayerState(bus);
  }, 1000) as unknown as number;
}

function stopPolling(): void {
  if (pollInterval !== null) {
    clearInterval(pollInterval);
    pollInterval = null;
    logDebug("Stopping poll-based state monitoring");
  }
}

async function run(): Promise<void> {
  main();
  await keepAlive();
}

if (import.meta.main) {
  run().catch(console.error);
}
