Build a single-page IT Project Management web app with a Kanban board for UOB's internal IT PMO. This is an internal demo/training tool — do not use UOB's real logo, trademarks, or imitate any official UOB system. Use a neutral "UOB IT PMO" text wordmark and a corporate blue palette only.

Hard constraints
Vanilla HTML, CSS and JavaScript only. No React, Vue, jQuery, Tailwind, build step, bundler, or npm. No frameworks of any kind.
Single file: index.html containing all markup, a <style> block and a <script> block. It must run by double-clicking the file — no server required.
Form submissions go through FormSubmit (formsubmit.co) via its AJAX JS endpoint. No other backend.
No persistence. Board state lives in a JavaScript array in memory only. Do not use localStorage, sessionStorage, IndexedDB, cookies, or any storage API. A page refresh resets the board to the seeded demo data — that is intended behaviour, and the UI should show a small note saying so.
External resources: none. No CDN scripts, no Google Fonts, no image files. Use a system font stack and inline SVG or Unicode glyphs for icons.
Kanban board

Four fixed columns, left to right:

Column	Meaning
Backlog	Logged, not yet scheduled
In Progress	Actively being worked
Blocked	Waiting on a dependency, vendor or approval
Done	Completed / closed

Requirements:

Columns render side by side on desktop (CSS flex or grid), stack vertically below 768px.
Each column header shows the column name and a live task count badge.
Each task renders as a card showing: task ID, title, project/workstream, assignee, priority pill, due date, and a category tag.
Drag and drop cards between columns using the native HTML5 Drag and Drop API (draggable="true", dragstart, dragover, drop). Show a visual drop-target highlight on the column being hovered. Moving a card updates the task's status in the data array and re-renders.
Also provide a keyboard-accessible fallback: a small "Move ▸" control on each card that lets the user pick a target column (so the app works without a mouse).
Cards are colour-coded on the left border by priority: Critical = red, High = amber, Medium = blue, Low = grey.
Overdue tasks (due date in the past and status ≠ Done) get a subtle red "Overdue" badge.
A delete (×) button on each card removes it from the array, with a confirm step that is not a native confirm() dialog — use an inline "Delete? Yes / No" toggle inside the card.
Add Task form

A simple form, either in a left sidebar panel or a modal opened by an "+ Add Task" button in the header.

Fields:

Field	Type	Notes
Task Title	text	required, max 80 chars
Description	textarea	optional, max 500 chars
Project / Workstream	select	Core Banking Upgrade, Digital Channels, Cybersecurity Uplift, Data & Analytics, Infrastructure & Cloud, Vendor Management
Category	select	Application Development, Infrastructure, Cybersecurity, Data, Compliance, Vendor
Assignee	text	required
Priority	select	Critical, High, Medium, Low (default Medium)
Due Date	date	required, must not be in the past
Status	select	Backlog, In Progress, Blocked, Done (default Backlog)

Behaviour:

Client-side validation before submit. Show inline error text under each invalid field; do not use alert().
On valid submit: generate a task ID in the format UOB-ITPM-#### (zero-padded incrementing counter), add the task to the in-memory array, re-render the board, reset the form, and show a transient success toast.
Optimistic UI: the card appears on the board immediately; the FormSubmit call happens in parallel. If the network call fails, keep the card but show a non-blocking warning toast ("Card added locally — email notification failed").
Disable the submit button and show a "Sending…" state while the request is in flight.
FormSubmit integration

Use the FormSubmit AJAX JSON endpoint from JavaScript — not a plain HTML form POST, so the page never navigates away.

js
const FORMSUBMIT_ENDPOINT = "https://formsubmit.co/ajax/YOUR_EMAIL@example.com";

async function notifyNewTask(task) {
  const res = await fetch(FORMSUBMIT_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({
      _subject: ⁠ [UOB IT PMO] New task ${task.id}: ${task.title} ⁠,
      _template: "table",
      _captcha: "false",
      "Task ID": task.id,
      Title: task.title,
      Description: task.description,
      Project: task.project,
      Category: task.category,
      Assignee: task.assignee,
      Priority: task.priority,
      "Due Date": task.dueDate,
      Status: task.status,
      "Submitted At": new Date().toISOString(),
    }),
  });
  if (!res.ok) throw new Error(⁠ FormSubmit failed: ${res.status} ⁠);
  return res.json();
}

Notes to honour in the build:

Put FORMSUBMIT_ENDPOINT in a clearly marked config constant at the top of the script so the email address can be swapped in one place.
Add a short HTML comment above it explaining that FormSubmit requires a one-time activation: the first submission triggers a confirmation email to that address, and submissions only deliver after the link in it is clicked.
Wrap the call in try/catch. A FormSubmit failure must never break the board.
Never send the user's email address anywhere except this endpoint.
Extras
Filter bar above the board: filter by Project, Assignee (free-text contains), and Priority. Filtering is pure client-side over the in-memory array.
Summary strip in the header: total tasks, count per status, and overdue count — all live.
Seed the board with 8 realistic demo tasks spread across the four columns (e.g. "Migrate FX pricing service to AWS", "Patch CVE-2025-XXXX on branch teller VDI", "UAT sign-off for mobile onboarding release 4.2") so the board is not empty on first load.
Code quality
Semantic HTML: <header>, <main>, <section>, <form>, <label for> on every input.
Accessible: visible focus rings, aria-label on icon-only buttons, aria-live="polite" on the toast region, colour never the only signal (priority pills carry text too).
CSS custom properties for the palette and spacing scale; no !important.
JavaScript organised as small named functions — renderBoard(), renderCard(), addTask(), moveTask(), deleteTask(), applyFilters(), showToast(), notifyNewTask() — with a single state = { tasks: [], filters: {} } object as the source of truth. Re-render from state; no direct DOM mutation of card contents outside renderBoard().
Escape all user-supplied strings before inserting into HTML (write a small escapeHtml() helper) — no raw innerHTML with unsanitised input.
Comment each major section.
Deliverable

One file, index.html. After writing it, list in your reply: the config constant to change, the FormSubmit activation step, and one paragraph on what would need to change to make the board persistent.