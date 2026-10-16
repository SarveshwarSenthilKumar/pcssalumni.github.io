# Yearbook files

Place optimized PDF yearbooks in this directory and run:

```powershell
node scripts/index-yearbooks.mjs
```

The indexer recognizes any PDF filename containing a four-digit year. For 2002,
include `junior` or `senior` in the filename. Examples:

- `YB-1959.pdf`
- `PCSS-1984-yearbook.pdf`
- `YB-2002-Junior.pdf`
- `YB-2002-Senior.pdf`

The generated `data/yearbooks.json` catalogue prefers local files. When no local
file exists, it uses a URL from `data/yearbook-sources.json`, then falls back to
the Internet Archive copy.

Do not commit a PDF larger than 100 MiB. GitHub blocks it, and Git LFS is not
supported by GitHub Pages. Keep the complete published Pages artifact under 1 GB.

