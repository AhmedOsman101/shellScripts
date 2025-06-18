import cleanurl
import validators
import sys


def isValidUrl(url: str) -> bool:
    return validators.url(url) is True


def main():
    # Access command-line arguments
    if len(sys.argv) == 2:
        url = sys.argv[1]
    else:
        url = input("Enter a URL to clean: ")

    rawUrl = cleanurl.cleanurl(url)
    if rawUrl is not None and isValidUrl(rawUrl.url):
        print(rawUrl.url)
        exit(0)
    else:
        sys.stderr.write("\033[31mError parsing the URL\033[0m\n")
        exit(1)


if __name__ == "__main__":
    main()
