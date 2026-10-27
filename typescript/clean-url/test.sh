#!/usr/bin/env bash

# ---  Main script logic --- #
URLS=(
  "https://example.com/path#fragment"
  "https://www.anothersite.org/article?id=123&si=12345"
  "https://www.example.com/page?utm_source=email&utm_medium=campaign&ref=sidebar#section-1"
  "http://www.google.com/search?q=test+query&oq=test&aqs=chrome.0.69i59j69i60l2.1234j0j1&sourceid=chrome&ie=UTF-8"
  "invalid-url-no-scheme.com"
  "https://www.linkedin.com/in/ahmad-ali-othman-5b503324a/?lipi=urn%3Ali%3Apage%3Ad_flagship3_feed%3BHk5GcUfuTNCs4Jnx7x6%2Bqw%3D%3D"
  "https://example.com/?url=https%3A%2F%2Fclean-me.com%2Fpath%3Fparam%3Dvalue"
  "https://www.google.com/search?client=firefox-b-d&channel=entpr&q=hello+word"
  "https://www.example.com/just/a/path"
  "http://malicious.com/<script>alert('xss')</script>"
  "ftp://ftp.example.com/file.txt"
  "https://www.example.com/path/to/page?param1=value1&param2=value2"
  "https://www.fragment-only.net/page#bottom"
  "https://www.google.com/search?q=another+query&tbm=isch"
  "https://example.com/path?query=value#fragment"
  "http://redirect.com/?q=https%3A%2F%2Ffinal-destination.org%2F"
)

for url in "${URLS[@]}"; do
  bun run index.ts -- "${url}"
done
