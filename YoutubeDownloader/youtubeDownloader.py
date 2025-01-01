import pygame
import os
from pytubefix import Playlist,YouTube


with open("downloadUrls.txt","r") as file:
          urls = file.readlines()

for url in urls:
        try:
                py = Playlist(url.strip())
                playlist_folder = py.title
                if not os.path.exists(playlist_folder):
                        os.makedirs(playlist_folder)

                print(f"Downloading playlist: {py.title }")

                num = 0
                for vid in py.videos:
                        num += 1
                        print(f"Downloading video {num}: {vid.title}")
                        vid.streams.get_highest_resolution().download(output_path=playlist_folder)
                        print(f"Video {num} downloaded successfully.")
        except:
                py = YouTube(url.strip())  
                py.streams.get_highest_resolution().download()
                print("Video downloaded")


## to run a music after finsih 

# pygame.mixer.init()
# pygame.mixer.music.load("dd.mp3")
# pygame.mixer.music.play()
# while pygame.mixer.music.get_busy():
#     pygame.time.Clock().tick(10)
