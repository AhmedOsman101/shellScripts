#!/usr/bin/env -S deno run -A
import type { Message, MessageBus } from "dbus-next";
import { sessionBus, type Variant } from "dbus-next";

const POLYBAR_MODULE = "media";
const MAX_TRACK_LENGTH = 35;

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

function formatTrackInfo(metadata: Metadata): string {
  const artists = metadata["xesam:artist"] || [];
  const artist = artists.length > 0 ? artists[0] : "Unknown Artist";
  const title = metadata["xesam:title"] || "Unknown Title";

  const track = `${artist} - ${title}`;

  if (track.length <= MAX_TRACK_LENGTH) {
    return track;
  }

  return `${track.substring(0, MAX_TRACK_LENGTH - 3)}...`;
}

function sendPolybarMessage(hook: string, value: string): void {
  const command = new Deno.Command("polybar-msg", {
    args: ["action", `#${POLYBAR_MODULE}.hook.${hook}`, value],
    stdout: "null",
    stderr: "null",
  });

  command.spawn();
}

function updateMediaHook(): void {
  const activePlayers = Array.from(players.values()).filter(
    p => p.playbackStatus !== "Stopped"
  );

  if (activePlayers.length === 0) {
    sendPolybarMessage("media", "");
    sendPolybarMessage("playpause", "0");
    sendPolybarMessage("previous", "0");
    sendPolybarMessage("next", "0");
    return;
  }

  const player = activePlayers[0];
  sendPolybarMessage("media", formatTrackInfo(player.metadata));

  const playpauseState = player.playbackStatus === "Playing" ? "1" : "2";
  sendPolybarMessage("playpause", playpauseState);
  sendPolybarMessage("previous", "1");
  sendPolybarMessage("next", "1");
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

  try {
    const proxy = await bus.getProxyObject(busName, "/org/mpris/MediaPlayer2");

    if (
      !Object.keys(proxy.interfaces).includes("org.mpris.MediaPlayer2.Player")
    ) {
      return;
    }

    proxy.getInterface("org.mpris.MediaPlayer2.Player");
    const propertiesInterface = proxy.getInterface(
      "org.freedesktop.DBus.Properties"
    );

    const metadata = (await propertiesInterface.Get(
      "org.mpris.MediaPlayer2.Player",
      "Metadata"
    )) as Variant<Metadata>;
    const playbackStatus = (await propertiesInterface.Get(
      "org.mpris.MediaPlayer2.Player",
      "PlaybackStatus"
    )) as string;

    players.set(busName, {
      busName,
      playbackStatus: playbackStatus as "Playing" | "Paused" | "Stopped",
      metadata: metadata.value,
    });

    updateMediaHook();

    propertiesInterface.on(
      "PropertiesChanged",
      (
        iface: string,
        changed: Record<string, Variant<unknown>>,
        _invalidated: string[]
      ) => {
        if (iface === "org.mpris.MediaPlayer2.Player") {
          const state = players.get(busName);
          if (!state) return;

          if (changed.Metadata) {
            state.metadata = changed.Metadata.value as Metadata;
          }
          if (changed.PlaybackStatus) {
            state.playbackStatus = changed.PlaybackStatus.value as
              | "Playing"
              | "Paused"
              | "Stopped";
          }

          updateMediaHook();
        }
      }
    );
  } catch (error) {
    console.error(`Error connecting to ${busName}:`, error);
  }
}

function handlePlayerRemoved(busName: string): void {
  if (!isMPRISPlayer(busName)) {
    return;
  }

  if (players.delete(busName)) {
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

    for (const name of names) {
      await handlePlayerAdded(bus, name);
    }
  } catch (error) {
    console.error("Error listing active players:", error);
  }
}

function main(): void {
  console.log("Starting MPRIS Media Control for Polybar...");

  const bus = sessionBus();

  bus.on("connect", async () => {
    console.log("Connected to DBus session bus");
    await listActivePlayers(bus);
  });

  bus.on("message", async (msg: Message) => {
    if (
      msg.interface === "org.freedesktop.DBus" &&
      msg.member === "NameOwnerChanged"
    ) {
      const [name, oldOwner, newOwner] = msg.body as [string, string, string];

      if (newOwner && !oldOwner) {
        await handlePlayerAdded(bus, name);
      } else if (!newOwner && oldOwner) {
        handlePlayerRemoved(name);
      }
    }
  });

  bus.on("error", (error: Error) => {
    console.error("DBus error:", error);
  });
}

if (import.meta.main) {
  main();
}
