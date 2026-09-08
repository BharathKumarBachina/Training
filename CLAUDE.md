# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-file Kanban board demo for a fictional "UOB IT PMO" (internal training tool, not an official UOB system — no real logo/branding, corporate-blue text wordmark only). The full spec is in `requirment.md`; treat it as the source of truth for scope and constraints.

Two files matter:

- `index.html` — the entire app (markup, `<style>`, `<script>`).
- `requirment.md` — the requirements the app was built to.

## Hard constraints (from the spec — do not break these)

- Vanilla HTML/CSS/JS only. No frameworks, libraries, CDN scripts, web fonts, image files, build step, or npm.
- Must stay one file and must run from `file://` by double-clicking. No server.
- **No persistence.** Never introduce localStorage, sessionStorage, IndexedDB, cookies or any storage API. A refresh resetting to seed data is intended, and the header note says so.
- The only backend call is the FormSubmit AJAX endpoint (`FORMSUBMIT_ENDPOINT`, a config constant at the top of the script). The user's email must never be sent anywhere else.
- No `alert()` / `confirm()`; no `!important`; every input has a `<label for>`; icon-only buttons carry `aria-label`.

## Running and testing

There is no build, lint or test runner. Open the file directly:

```sh
open index.html
```

Verification is done with headless Chrome. Render check / console errors:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
  --enable-logging=stderr --virtual-time-budget=2000 --dump-dom "file://$PWD/index.html" 2>&1 >/dev/null | grep CONSOLE
```

Screenshot at desktop width:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
  --hide-scrollbars --window-size=1440,1000 --screenshot=out.png "file://$PWD/index.html"
```

Gotchas learned while verifying:

- Headless Chrome clamps the window to a 500px minimum width, so `--window-size=390,...` does **not** test the mobile breakpoint. Load the page in a 390px-wide `<iframe>` from a host page (run Chrome with `--allow-file-access-from-files`) to test the stacked layout.
- For behaviour smoke tests, copy `index.html` to a scratch file, stub `window.fetch` before the main script so no real FormSubmit request goes out, append a test `<script>` that drives the DOM and writes results into a `<pre>`, then `--dump-dom` and read that element.
- Author `display: flex` on `.modal-backdrop` beats the UA `[hidden]` rule; the explicit `.modal-backdrop[hidden] { display: none; }` rule must stay.

## Architecture of `index.html`

Everything lives in one IIFE. Data flow is strictly **state → render**:

- `state = { tasks, filters, pendingDeleteId, nextIdNumber }` is the single source of truth. `pendingDeleteId` holds the card currently showing the inline "Delete? Yes / No" toggle; it is state (not a DOM tweak) so the toggle survives re-renders.
- `renderBoard()` rebuilds all four columns from `applyFilters()` and then calls `renderSummary()` (always over all tasks, not the filtered set) and `renderFilterCount()`. `renderCard()` returns an HTML string. **Do not mutate card DOM anywhere else** — change state and call `renderBoard()`.
- Mutations: `addTask()`, `moveTask()`, `deleteTask()` each update `state` and re-render.
- All user-supplied strings go through `escapeHtml()` before being placed in `innerHTML`; toast text uses `textContent`.
- Board interaction uses event delegation on `#board` (`initBoardEvents`): clicks keyed by `data-action` (`delete` / `confirm-delete` / `cancel-delete`), the `Move ▸` `<select>` as the keyboard fallback, and native HTML5 drag & drop (`dragstart` / `dragover` / `drop`) with a `.drop-target` class on the hovered column.
- Add-task flow (`handleSubmit`): validate → inline errors via `setFieldError` → optimistic `addTask()` → button shows "Sending…" → `notifyNewTask()` in try/catch → warning toast on failure. FormSubmit failure must never block or remove the card.
- Column order, project/category/priority lists and their meanings are the `STATUSES`, `PROJECTS`, `CATEGORIES`, `PRIORITIES` constants; selects are populated from them via `populateSelect()`, so add options there, not in the markup.
- Task IDs are `UOB-ITPM-####` from `generateTaskId()`; seed tasks consume 0001–0008, so the first user-created task is 0009.
- Seed due dates are computed relative to today (`daysFromToday`) so the Overdue badge always has examples. Overdue = due date before today **and** status not Done.
- Palette and spacing are CSS custom properties on `:root`; priority colours are applied via `[data-priority]` attribute selectors on both the card border and the pill. Columns stack below 768px.
