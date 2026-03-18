# ENA Umbrella Project Management

## Overview

ENA umbrella projects are top-level projects used to group related sub-projects (child projects) under a single accession. 
Umbrella projects can only be created and updated from the command line, by using `curl` to submit XML files you have created.
This repository provides a simple interactive TUI (`tui.sh`) to generate the necessary XML files (`project.xml` and `submission.xml`) based on user input, and to submit them to the [ENA Webin REST submission API](https://www.ebi.ac.uk/ena/submit/drop-box/submit/).

Covered scenarios:

- **Create** a new umbrella project (standalone or with child sub-projects)
- **Update** an existing umbrella project (metadata and/or child sub-projects)
- **Release** (make public) an umbrella project

## Repository Contents

| File | Description |
|------|-------------|
| `tui.sh` | Interactive TUI |
| `parse-receipt.py` | Python script to parse the XML receipt returned by the ENA server |
| `templates/` | XML templates used by `tui.sh` |

### Templates

| File | Description |
|------|-------------|
| `docs/blank-umbrella-project.xml` | Blank template for a new standalone umbrella project |
| `docs/blank-umbrella-project-with-childs.xml` | Blank template for a new umbrella project with child sub-projects |
| `docs/updated-umbrella-project.xml` | Blank template for updating an existing umbrella project |
| `templates/new-submission.xml` | Submission action file for creating a new project (`ADD` + `HOLD`) |
| `templates/update-submission.xml` | Submission action file for updating an existing project (`MODIFY`) |
| `templates/release-submission.xml` | Submission action file for releasing a project (`RELEASE`) |

## Prerequisites

- `whiptail` (for the TUI):
  - pre-installed on most Debian/Ubuntu systems
  - `apt install whiptail` if missing
- `curl` (for HTTP submissions):
  - `apt install curl`
- Python3 with the [`untangle`](https://pypi.org/project/untangle/) library (for receipt parsing):
  - `apt install python3-untangle` (preferred)
  - `pip install untangle`
- An [ENA Webin account](https://www.ebi.ac.uk/ena/submit/webin/login)

## Setup

Create a `.credential` file in the repository root containing your ENA Webin credentials on a single line:

```
Webin-XXXXX password
```

> **Note:** Keep this file private. It is not tracked by git (add it to `.gitignore`).

## Usage — Interactive TUI

Launch the TUI with:

```bash
bash tui.sh
```

The main menu offers five actions:

```
1. Create a new umbrella project
2. Update an existing umbrella project
3. Release an umbrella project
4. Submit to ENA
5. Quit
```

### 1. Create a new umbrella project

The TUI will guide you through:

1. Whether the project has child sub-projects (yes/no)
2. If yes: how many child slots to generate
3. A hold date (private until date), defaulting to today + 2 years

It generates two working files in the project directory:

- `project.xml` — fill in `center_name`, `alias`, `NAME`, `TITLE`, `DESCRIPTION`, and child accessions if applicable
- `submission.xml` — `HoldUntilDate` is pre-filled

Edit project metadata and child accessions as needed, then proceed to submission.

### 2. Update an existing umbrella project

The TUI will ask:

1. Whether you have an existing project XML to use as base (yes/no)
   - If yes: provide the file path — it will be copied to `project.xml`
   - If no: a blank update template is generated
2. Whether to add child sub-projects (yes/no)
   - If yes: how many child slots to inject
3. The accession of the project to update (format: `PRJEBxxxxxx`)
   - The `accession` attribute is set on the `<PROJECT>` element automatically
   - Works whether the source XML already has an `accession` attribute or not

It generates:

- `project.xml` — fill in fields and/or child accessions as needed; `accession` is pre-filled
- `submission.xml` — ready to use

Edit project metadata and child accessions as needed, then proceed to submission.

### 3. Release an umbrella project

The TUI will ask for the accession of the project to release (format: `PRJEBxxxxxx`).
It generates `submission.xml` with the accession pre-filled, then immediately offers
to proceed to submission.

### 4. Submit to ENA

Before submitting, the TUI checks:

- `.credential` file exists
- `submission.xml` exists
- `project.xml` exists (not required for release)

You will be asked to choose between:

- **Test** — validates against the ENA dev server, no data is registered
- **Production** — real submission; requires explicit typed confirmation (`YES`)

On success, receipt files are saved:

- `server-receipt.xml` — raw XML receipt from ENA
- `server-receipt.txt` — tabular summary (alias, accession, status)

## ENA API Endpoints

| Environment | URL |
|-------------|-----|
| Test (dev)  | `https://wwwdev.ebi.ac.uk/ena/submit/drop-box/submit/` |
| Production  | `https://www.ebi.ac.uk/ena/submit/drop-box/submit/` |

## References

- [ENA Programmatic Submission Documentation](https://ena-docs.readthedocs.io/en/latest/submit/general-guide/programmatic.html)
- [ENA Umbrella Projects Guide](https://ena-docs.readthedocs.io/en/latest/submit/project/umbrella.html)
- [ENA Webin Portal](https://www.ebi.ac.uk/ena/submit/webin/login)

## How to report issues?

We welcome you to report any [issues](https://github.com/bigey/ENA-umbrella-project-management/issues) in this document or script.

## Citing

If you use this document or script in your research, please cite:

BibTeX

```bibtex
@misc{bigey2026,
  author       = {Bigey, Frédéric},
  title        = {ENA Umbrella Project Management},
  year         = {2026},
  howpublished = {\url{https://github.com/bigey/ENA-umbrella-project-management}},
  note         = {accessed 2026-03-18}
}
```
Biblatex

```biblatex
@software{bigey2026,
  author       = {Bigey, Frédéric},
  title        = {ENA Umbrella Project Management},
  year         = {2026},
  version      = {v1.0.0},
  url          = {https://github.com/bigey/ENA-umbrella-project-management},
  note         = {accessed 2026-03-18}
}
```