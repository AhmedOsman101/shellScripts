# Convert blameInfos array to entries with index (.key) and value (.value)
.blameInfos | to_entries
# Filter entries where the line number (index + 1) is in changedLines
| map(select(.key + 1 | IN($changedLines[])))
# Group by the author key (e.g., "John Doe <john@example.com>")
| group_by(.value.author + .value.email)
# Transform each group into a key-value pair
| map({
  key: (.[0].value.author + " <" + .[0].value.email + ">"),
  value: {
    count: length,              # Number of changes by this author
    lines: map(.key + 1)        # Array of changed line numbers
  }
})
# Convert array of {key, value} pairs back to an object
| from_entries

