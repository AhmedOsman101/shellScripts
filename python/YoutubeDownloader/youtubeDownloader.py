import sys
from os import makedirs
from pathlib import Path
from plyer import notification
from pytubefix import Playlist, YouTube
from tqdm import tqdm
import time


HELP_TEXT = """
YouTube Downloader Script

Description:
  This script allows you to download YouTube videos or playlists. You can either provide URLs directly via command-line arguments or specify a file containing a list of URLs to download.

Usage:
  python script_name.py [OPTIONS] [URLS]

Options:
  -f <filename>   Specify a file containing URLs to download. The default file is 'urls.txt'.
                  If the file does not exist or contains no URLs, an error will be displayed.

  --help          Display this help text and exit.

Arguments:
  URLS            Provide one or more YouTube video or playlist URLs directly as command-line arguments.
                  URLs must include 'youtube.com' or 'youtu.be'. Playlists should include the 'list=' parameter.

Examples:
  1. Download from a file (default filename: 'urls.txt'):
    python script_name.py -f urls.txt

  2. Download specific URLs:
    python script_name.py https://www.youtube.com/watch?v=EXAMPLE https://youtu.be/EXAMPLE2
"""


def readUrlsFromFile(filename: str = "urls.txt") -> str:
  if Path(filename).exists():
    with open(filename, "r") as file:
      urls = file.readlines()
      if (len(urls) < 1):
        print(f"File: {filename} is empty!")
        exit()
  else:
    print(f"File: {filename} doesn't exist!")
    exit()
  return urls


def notify(title: str, msg: str = ""):
  """
  Purpose: send notifications to the user
  """
  notification.notify(
      title=title,
      message=msg,
      app_name='yt downloader',
      timeout=5
  )

def handleOnProgress(stream, chunk, bytes_remaining):
    total_size = stream.filesize
    bytes_downloaded = total_size - bytes_remaining
    percent_completed = int((bytes_downloaded / total_size) * 100)
    tqdm.write(f"Progress: {percent_completed}%")

def downloadVideo(url: str, playlist_folder: str = ""):
  """
  Purpose: Extracting the logic for downloading videos
  """
  video = YouTube(url.strip(),on_progress_callback=handleOnProgress)
  notify("Downloading...")
  print(f"Downloading video: {video.title}")
  fileSize = video.streams.get_highest_resolution().filesize
  with tqdm(total=fileSize,unit="B",unit_scale=True,desc=video.title) as progressBar:
    if (playlist_folder):
      video.streams.get_highest_resolution().download(output_path=playlist_folder)
    else:
      video.streams.get_highest_resolution().download()
    progressBar.update(fileSize)
  if video:
    notify("Download Finished!", f"{video.title} Downloaded successfully")
    print("Video downloaded successfully.")
  else:
    notify("Download Failed!")


def downloadPlaylist(url: str):
  """
  Purpose: Extracting the logic for downloading playlists
  """
  playlist = Playlist(url.strip())
  playlist_folder = playlist.title
  if not Path(playlist_folder).exists():
    makedirs(playlist_folder)

  print(f"Downloading playlist: {playlist.title}")

  try:
    for url in playlist.video_urls:
      downloadVideo(
          url=url,
          playlist_folder=playlist_folder
      )
    notify("Download Finished!", f"{playlist.title} Downloaded successfully")
  except:
    notify("Download Failed!")


def main():
  argv = sys.argv
  argc = len(argv)

  if argc == 1:
    urls = readUrlsFromFile()
  elif argc == 2 and argv.count("--help"):
    print(HELP_TEXT)
    exit()
  elif argc == 3 and argv[1] == "-f":
    urls = readUrlsFromFile(argv[2])
  elif argc > 1:
    urls = argv[1:]

  for url in urls:
    try:
      if not (url.count("youtube.com") or url.count("youtu.be")):
        print("Invalid url")
        exit()
      elif (url.count("list=")):
        downloadPlaylist(url)
      else:
        downloadVideo(url)
    except Exception as e:
      print("Error: ", e)
      notify("Download Failed!")


if __name__ == "__main__":
  main()
