from rich import print
from ytmusicapi import YTMusic, OAuthCredentials


def main():
  ytm = YTMusic("browser.json")
  playlists = ytm.get_library_playlists()
  i = 1
  for item in playlists:
    print(f"{i}) {item['title']} - {item['description']}")
    i += 1

  playlistIndex = int(input("Choose a playlist by number: ")) - 1
  playlistId = playlists[playlistIndex]['playlistId']
  playlist = ytm.get_playlist(playlistId)

  for song in playlist['tracks']:
    artists = ", ".join(s["name"] for s in song['artists'])
    print(f"{song['title']} - {artists}")


if __name__ == "__main__":
  main()
