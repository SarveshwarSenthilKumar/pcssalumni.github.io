# Repository weaknesses and proposed improvements

Reviewed: 2026-10-16. Scope: the entire repository, including Quarto pages, shared assets, catalogue data, recovery scripts, documentation and deployment workflow.

Security follow-up on 2026-10-16: the subsequent redirect investigation implemented per-hop recovery restrictions (19), catalogue URL/type validation (23), pull-request security/build validation (24), pinned Quarto/Python CI versions (part of 26), and build subprocess error handling (27). See [SECURITY.md](SECURITY.md) for verified findings, implemented protections, checks and the separate legacy-host remediation still required. The numbered findings below preserve the original review evidence; this update supersedes their pre-fix descriptions where applicable.

This is an improvement backlog, not a record of implemented fixes. Findings come from local source inspection. External links, remote permissions and preservation masters were not independently verified. A rendered build could not be checked because Quarto is not installed in the current shell. Priorities: **P1** = correctness, preservation or access; **P2** = usability and maintainability; **P3** = enhancement.

## Publishing and catalogue correctness

### 1. Local yearbook PDFs are not explicitly included in the publication resources — P1

- **Evidence:** `scripts/index-yearbooks.mjs` emits `yearbooks/...pdf` URLs into a JSON manifest. `_quarto.yml` includes that JSON but has no `yearbooks/**` resource entry; `scripts/build-site.mjs` does not copy PDFs. Those links are created dynamically, rather than appearing in source HTML for resource discovery.
- **Impact:** Adding a local PDF can produce a catalogue link without ensuring that the PDF reaches `_site`.
- **Proposed solution:** Explicitly copy indexed local PDFs into the matching output paths or declare PDF resources in Quarto. Check the total publication size before uploading.
- **Verification:** Build with a small fixture PDF and confirm every local manifest URL resolves inside `_site`.

### 2. The validator does not check local URLs inside the catalogue — P1

- **Evidence:** `scripts/validate-site.mjs` checks HTML references and rejects selected manifest hosts, but never checks that a local `book.url` exists.
- **Impact:** Missing PDFs can pass deployment validation, including the failure described above.
- **Proposed solution:** Validate every manifest record against a schema; resolve local URLs beneath `_site` and require readable PDF files. Require suitable HTTPS URLs for external copies.
- **Verification:** Remove a fixture PDF from the build and require validation to fail with its edition key and missing path.

### 3. Availability totals double-count local books — P2

- **Evidence:** In `scripts/index-yearbooks.mjs`, `onlineCount` includes all books with a URL, including local books, but the log prints `onlineCount + localCount` as available.
- **Impact:** Maintainers see inflated availability totals whenever local books exist.
- **Proposed solution:** Count availability once, or report mutually exclusive local, external, pending and missing totals.
- **Verification:** One local and one external fixture should report two available editions.

### 4. Filename recognition disagrees with the live recovery script — P1

- **Evidence:** `recover-live-yearbooks.py` downloads `YB-2002-J.pdf` and `YB-2002-S.pdf`. The indexer's `identify()` recognizes `junior`, `senior`, `jr` and `sr`, but not standalone `J` or `S`.
- **Impact:** Copying those recovered files directly into `yearbooks/` produces the unused key `2002`, leaving both expected editions unmatched.
- **Proposed solution:** Support the recovery filenames explicitly, normalize names during import, and reject ambiguous 2002 names with an actionable message.
- **Verification:** Both recovery filenames must map to their respective junior and senior catalogue keys.

### 5. Duplicate and unrecognized local PDFs are silently ignored or overwritten — P2

- **Evidence:** The indexer uses `localFiles.set(key, ...)` without duplicate checks; keys outside `expected` never appear in the generated catalogue.
- **Impact:** A maintainer can unknowingly publish the wrong duplicate or believe an added PDF was indexed when it was not.
- **Proposed solution:** Report duplicates, unknown years and ambiguous names. Require an explicit choice for duplicate editions rather than depending on traversal order.
- **Verification:** Duplicate-year and unknown-year fixtures must produce clear diagnostics.

### 6. Source priority and documentation conflict — P2

- **Evidence:** `yearbooks/README.md` describes local files, source overrides, then an Internet Archive fallback. The indexer actually prefers Google Drive links before `yearbook-sources.json`, and has no automatic Wayback URL fallback.
- **Impact:** A documented source override may have no effect, and maintainers may expect a fallback that does not exist.
- **Proposed solution:** Define one source-priority policy, implement it explicitly and document the exact order. Prefer an intentional per-edition override if that is its purpose.
- **Verification:** Provide local, Drive and source URLs for one fixture and verify the documented winner.

### 7. Preservation status is inferred globally rather than verified per edition — P1

- **Evidence:** The indexer marks any otherwise unavailable edition as `preserved` when `preservation.yearbooks.complete` is true. `data/preservation-status.json` contains aggregate counts rather than per-edition integrity records.
- **Impact:** An aggregate claim can conceal a missing or changed individual master.
- **Proposed solution:** Keep an edition-level preservation manifest containing size, SHA-256, page count, verification date and storage reference. Derive summary status from those records.
- **Verification:** Removing one verified edition record must affect only that edition and reduce the summary total.

### 8. Public completion claims and home-page counts can become stale — P2

- **Evidence:** `index.qmd` hard-codes decade counts; `yearbooks.qmd`, `archive.qmd` and `about.qmd` hard-code recovery and availability claims.
- **Impact:** Future catalogue changes or inaccessible copies can leave confident public statements out of sync with actual access.
- **Proposed solution:** Generate collection counts and dated status summaries from validated data. Distinguish recovered masters from publicly accessible copies.
- **Verification:** Changing a fixture's availability should update the relevant counts and wording consistently.

## Accessibility and visitor experience

### 9. The catalogue has no usable JavaScript-free fallback — P1

- **Evidence:** `yearbooks.qmd` contains an empty grid, while `assets/yearbooks.js` fetches and renders every edition. The `noscript` message says JavaScript is needed for filtering, although links also depend on it.
- **Impact:** A script failure or disabled JavaScript prevents access to the entire catalogue.
- **Proposed solution:** Render the complete link list at build time and progressively enhance it with client-side filtering.
- **Verification:** With JavaScript disabled, all available yearbook links should remain accessible.

### 10. Search has no visible keyboard focus indicator — P1

- **Evidence:** `.search-box input` in `assets/styles.css` sets `outline: 0`; there is no replacement focus rule for the input or its container.
- **Impact:** Keyboard users can lose track of focus while searching.
- **Proposed solution:** Add a clear `:focus-visible` outline or `.search-box:focus-within` treatment, and review focus visibility across all controls.
- **Verification:** Navigate by keyboard at desktop and mobile widths and confirm the focused control is always visible.

### 11. Decade selection loses focus and exposes no selection state — P1

- **Evidence:** `renderFilters()` replaces all buttons after each click and marks selection only with an `active` CSS class.
- **Impact:** Keyboard focus can be lost when its button is removed, and assistive technology cannot reliably announce the selected decade.
- **Proposed solution:** Keep stable button elements, update `aria-pressed`, and preserve focus. Keep the result-count announcement concise.
- **Verification:** Select successive decades using the keyboard and verify retained focus and announced selection.

### 12. Mobile navigation depends entirely on JavaScript — P2

- **Evidence:** Below 900px, CSS hides `.site-nav`; `assets/site.js` is responsible for adding `open`.
- **Impact:** If the script fails, mobile users lose the main navigation.
- **Proposed solution:** Use a progressively enhanced menu or native disclosure. Add Escape-to-close and update the accessible button label as its state changes.
- **Verification:** Check navigation with scripts disabled and with keyboard-only interaction.

### 13. Catalogue error handling offers little recovery — P2

- **Evidence:** The fetch catch handler always suggests serving over HTTP, even when the failure is an HTTP error or malformed data. There is no retry or fallback link list.
- **Impact:** Visitors receive advice that may not address the actual problem.
- **Proposed solution:** Provide a retry action, a static catalogue fallback and a general connection/error message. Validate data before rendering.
- **Verification:** Simulate offline access, HTTP 404 and malformed JSON and confirm a useful recovery path for each.

### 14. Filters are not reflected in shareable URLs — P3

- **Evidence:** `assets/yearbooks.js` reads an initial `decade` parameter but never updates the URL after filtering or searching.
- **Impact:** Sharing or reloading a filtered catalogue loses the visitor's current selection.
- **Proposed solution:** Synchronize search and decade parameters with browser history and restore state on back/forward navigation.
- **Verification:** Filter, copy the URL into a fresh tab, then test browser back and forward.

### 15. Status labels assume every external source is Google Drive — P2

- **Evidence:** The renderer labels every `remote` book as `Google Drive copy`, although source overrides accept other hosts. The legend also labels the `preserved` category as an individual Google Drive copy, while the renderer treats it as a preserved copy awaiting hosting.
- **Impact:** Labels can misrepresent both hosting provider and public availability.
- **Proposed solution:** Separate preservation state, access state and hosting provider in the data model; generate consistent card labels and legend entries.
- **Verification:** Check local, Drive, non-Drive HTTPS, pending-hosting and missing fixtures.

## Recovery reliability and preservation

### 16. Wayback download limits are not enforced on streamed bytes — P1

- **Evidence:** `recover-wayback.py` filters on inventory `record.length`, but `download()` has no byte limit and writes until the response ends.
- **Impact:** A response larger than its inventory estimate can exceed the requested file-size budget.
- **Proposed solution:** Pass the byte limit to the downloader, check response metadata when available, and enforce the limit on every streamed chunk.
- **Verification:** A mocked response exceeding the limit must fail before promotion to the final file.

### 17. Recovery scripts accept weak evidence of file integrity — P1

- **Evidence:** Live yearbook recovery checks the `%PDF-` prefix; existing WordPress and Wayback targets are generally skipped based on existence. This does not establish complete, parseable content.
- **Impact:** Truncated files or incorrect responses can be accepted or repeatedly skipped as recovered.
- **Proposed solution:** Recheck existing files against recorded hashes and sizes. Parse PDFs and record page counts; validate media signatures and content types. Keep failed files out of completed manifests.
- **Verification:** Truncate fixtures, replace a PDF with HTML and alter an existing file; each must be detected.

### 18. Resumed PDF downloads do not verify range identity — P1

- **Evidence:** `recover-live-yearbooks.py` appends a `206` response to `.part` files without validating `Content-Range` or using an ETag/Last-Modified validator.
- **Impact:** A changed source or unexpected byte range can create a mixed or corrupt PDF that still starts with `%PDF-`.
- **Proposed solution:** Verify the returned range starts at the saved offset, use `If-Range` with a stored validator, and restart when identity cannot be established. Validate the completed PDF.
- **Verification:** Mock a changed ETag and an incorrect range offset and require a clean restart or explicit failure.

### 19. WordPress recovery's redirect behavior contradicts its stated restriction — P1

- **Evidence:** Its module description says it never follows rewritten hosts, but `open_url()` uses the default `urllib.request.urlopen`, which follows HTTP redirects. Canonicalizing the initial media URL does not constrain later redirects.
- **Impact:** A recovery request can leave the intended host and save unrelated content.
- **Proposed solution:** Apply an explicit redirect policy that checks scheme, host and permitted path on each hop. Record the final URL and validate the response before accepting it.
- **Verification:** Mock a redirect to another host and require rejection before downloading its body.

### 20. Partial recovery failure does not produce a failing process status — P2

- **Evidence:** All three recovery scripts record per-file failures and print totals, but their normal completion paths do not exit unsuccessfully when those totals contain failures.
- **Impact:** Automated runs can appear successful despite an incomplete recovery.
- **Proposed solution:** Preserve partial progress but exit nonzero when required downloads fail; offer an explicit best-effort option if needed and write a structured run summary.
- **Verification:** One failed fixture should retain successful downloads while returning a failing exit status.

### 21. Backups and provenance are described more strongly than they are reproducible — P2

- **Evidence:** README advises keeping masters outside the repository; `legacy/` is ignored. Aggregate preservation claims do not provide a documented restore procedure or per-item public citation trail. History and scholarship pages provide broad source notes rather than record-level citations.
- **Impact:** A future maintainer cannot reproduce all integrity checks, restore the master set from this checkout, or easily trace a disputed name or date.
- **Proposed solution:** Document backup locations and restore responsibilities without publishing private credentials. Keep portable checksums and provenance records with capture timestamps and source URLs. Add citations to specific historical assertions and recipient records, plus a correction/contact route.
- **Verification:** Perform a sample restore and trace selected public claims back to their specific source captures.

## Validation, automation and maintainability

### 22. Link validation is too narrow for future changes — P2

- **Evidence:** `validate-site.mjs` scans only top-level HTML, extracts only double-quoted `href`/`src` values with a regex, skips fragment validation and resolves local references from the site root rather than each document's directory.
- **Impact:** Nested pages, broken anchor links and additional resource attributes can escape checks or be checked incorrectly. Its string-prefix containment check also lacks a path-separator boundary.
- **Proposed solution:** Walk generated pages recursively, parse HTML, resolve references relative to each page and use a path-relative containment check. Check fragment targets and appropriate resource attributes.
- **Verification:** Include nested-page, missing-anchor, single-quoted-link and outside-root fixtures.

### 23. Catalogue rendering does not enforce a safe data contract — P2

- **Evidence:** The renderer escapes several text fields but inserts `year` and `state` directly into HTML. Escaping a URL attribute does not prohibit an unsafe URL scheme; current validation only blocks selected host patterns.
- **Impact:** A malformed future import can break markup or introduce unsafe links. This is a hardening gap, not evidence that current records are malicious.
- **Proposed solution:** Validate finite integer years, allowed state values and local/HTTPS URLs before publication. Prefer DOM APIs and text content for generated elements.
- **Verification:** Reject unexpected states, markup in numeric fields and `javascript:` URLs.

### 24. Pull requests receive no automated checks — P1

- **Evidence:** `.github/workflows/deploy.yml` triggers on pushes to `main` and manual dispatch, with no `pull_request` trigger or separate validation workflow.
- **Impact:** Contributors discover build and validation failures only after changes reach the deployment branch.
- **Proposed solution:** Add a read-only pull-request validation job that builds and checks the site. Keep deployment permissions and publishing confined to the main-branch deployment job.
- **Verification:** A pull request with a broken internal link should fail validation before merge.

### 25. Visual checks capture images but assert no behavior — P2

- **Evidence:** `scripts/visual-check.ps1` takes two screenshots using an unpinned `npx` package. It has no explicit catalogue-ready assertion or checks for filtering, menu operation, keyboard focus or console errors.
- **Impact:** A screenshot command can succeed while the key visitor workflows are broken or still loading.
- **Proposed solution:** Add a small browser smoke suite covering catalogue loading, both 2002 editions, filtering, mobile navigation and failed fetch behavior. Wait for meaningful ready states and store failure screenshots in CI.
- **Verification:** Deliberately break each supported interaction and confirm the relevant check fails.

### 26. Builds and review tooling are not fully reproducible — P2

- **Evidence:** CI selects Node major version 22 and installs Quarto without an explicit version; visual checking downloads a floating Playwright package. There is no package manifest/lockfile or documented Python version requirement. The indexer rewrites a tracked manifest timestamp on every build.
- **Impact:** Different environments can produce different results, and routine builds create timestamp-only data changes.
- **Proposed solution:** Document and pin supported tool versions, lock browser-test dependencies, and choose an explicit policy for generated catalogue data. Preserve its timestamp when content is unchanged or generate deployment-only output.
- **Verification:** Two clean builds using the same inputs should produce equivalent catalogue content without unexplained working-tree changes.

### 27. Build subprocess launch errors are not handled explicitly — P2

- **Evidence:** `scripts/build-site.mjs` listens for the child's `exit` event but not its `error` event.
- **Impact:** A missing executable can produce an unhandled spawn error instead of the intended actionable build diagnostic.
- **Proposed solution:** Reject on child `error`, include the missing tool and setup instruction in the message, and document prerequisites together in README.
- **Verification:** Run with Quarto unavailable and confirm a clear failure message and nonzero exit status.

### 28. Fixed catalogue size is duplicated across implementation and validation — P3

- **Evidence:** The indexer constructs a fixed expected-edition list, while the validator separately requires exactly 69 records; home-page counts are duplicated again.
- **Impact:** Adding a newly recovered edition requires coordinated code and content edits and can be rejected despite valid data.
- **Proposed solution:** Maintain one authoritative edition inventory. Derive counts from it and validate required keys, uniqueness and record completeness rather than an unrelated numeric constant.
- **Verification:** Add a legitimate fixture edition to the inventory and confirm all derived counts update consistently.

## Suggested implementation order

1. Fix local PDF publication, manifest-link validation, 2002 filename mapping and availability counting.
2. Harden streamed size limits, redirects, integrity checks, resume validation and recovery exit statuses.
3. Provide static catalogue access, visible focus and stable accessible filter controls.
4. Add pull-request validation and targeted browser smoke coverage; make builds reproducible.
5. Consolidate inventory/status data, add item-level provenance and document a tested restoration process.

## Review limits and completion criteria

No source behavior was changed for this review. No external downloads, remote link checks, deployment or browser accessibility audit were performed. The current shell has Node v22.17.0, but `quarto --version` fails because the executable is unavailable. Claims about remote availability and complete preservation remain unverified here. Before closing this backlog, run a clean build, output validation, targeted fixture checks and browser checks, then independently verify a sample of external copies and restored masters.
