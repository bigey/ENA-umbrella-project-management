# ENA Umbrella Project Management

Template files and scripts to create and manage umbrella projects in the [European Nucleotide Archive (ENA)](https://www.ebi.ac.uk/ena).

## Overview

ENA umbrella projects are top-level projects used to group related sub-projects (child projects) under a single accession. This repository provides XML templates and a Bash script to handle the full lifecycle of an umbrella project via the [ENA Webin REST submission API](https://www.ebi.ac.uk/ena/submit/drop-box/submit/).

Covered scenarios:

- **Create** a new umbrella project (standalone or with child sub-projects)
- **Update** an existing umbrella project
- **Release** (make public) an umbrella project

## Repository Contents

| File | Description |
|------|-------------|
| `blank-umbrella-project.xml` | Template for a new standalone umbrella project |
| `blank-umbrella-project-with-childs.xml` | Template for a new umbrella project with child sub-projects |
| `new-submission.xml` | Submission action file for creating a new project (`ADD` + `HOLD`) |
| `update-submission.xml` | Submission action file for updating an existing project (`MODIFY`) |
| `release-submission.xml` | Submission action file for releasing a project (`RELEASE`) |
| `umbrella-project-managment.sh` | Main Bash script to submit XML files to the ENA API |
| `parse-receipt.py` | Python script to parse the XML receipt returned by the ENA server |

## Prerequisites

- `curl` (for HTTP submissions)
- Python 3 with the [`untangle`](https://pypi.org/project/untangle/) library (`pip install untangle`)
- An [ENA Webin account](https://www.ebi.ac.uk/ena/submit/webin/login)

## Setup

Create a `.credential` file in the repository root containing your ENA Webin credentials on a single line:

```
Webin-XXXXX my-password
```

> **Note:** Keep this file private. It is not tracked by git (add it to `.gitignore`).

## Usage

### 1. Create a new umbrella project

**Without child sub-projects:**

1. Edit `blank-umbrella-project.xml` and fill in the `TODO` fields:

   - `center_name`: your institution name
   - `alias`: a unique local identifier for the project
   - `NAME`, `TITLE`, `DESCRIPTION`: project metadata

2. Edit `new-submission.xml` and set the `HoldUntilDate` to your intended release date (format: `YYYY-MM-DD`).

3. In `umbrella-project-managment.sh`, set:

   ```bash
   SUBMISSION_XML="new-submission.xml"
   UMBRELLA_PROJECT_XML="blank-umbrella-project.xml"
   ```

**With child sub-projects:**

1. Edit `blank-umbrella-project-with-childs.xml`, fill in the `TODO` fields, and replace `PRJEBxxxxxx` placeholders with the accessions of the existing child projects.

2. In `umbrella-project-managment.sh`, set:

   ```bash
   SUBMISSION_XML="new-submission.xml"
   UMBRELLA_PROJECT_XML="blank-umbrella-project-with-childs.xml"
   ```

### 2. Update an existing umbrella project with child sub-projects

1. Edit `blank-umbrella-project-with-childs.xml`, replace `PRJEBxxxxxx` placeholders with the accessions of the existing child projects.

2. In `umbrella-project-managment.sh`, set:

   ```bash
   SUBMISSION_XML="update-submission.xml"
   UMBRELLA_PROJECT_XML="blank-umbrella-project-with-childs.xml"
   ```

### 3. Release (make public) an umbrella project

1. Edit `release-submission.xml` and replace `PRJEBxxxxxx` with the accession of the umbrella project to release.

2. In `umbrella-project-managment.sh`, set:

   ```bash
   SUBMISSION_XML="release-submission.xml"
   # UMBRELLA_PROJECT_XML is not needed for release
   ```

### Running the script

There is two ways to run the script:

**Test submission** (validates against the ENA dev server, no data is actually submitted):

```bash
# In umbrella-project-managment.sh, keep:
SUBMISSION="false"

bash umbrella-project-managment.sh
```

**Real submission** (submits to the ENA production server):

```bash
# In umbrella-project-managment.sh, set:
SUBMISSION="true"

bash umbrella-project-managment.sh
```

On success, the server receipt is saved as:

- `server-receipt.xml` — raw XML receipt from ENA
- `server-receipt.txt` — tabular summary (alias, accession, external accession)

## ENA API Endpoints

| Environment | URL |
|-------------|-----|
| Test (dev)  | `https://wwwdev.ebi.ac.uk/ena/submit/drop-box/submit/` |
| Production  | `https://www.ebi.ac.uk/ena/submit/drop-box/submit/` |

## References

- [ENA Programmatic Submission Documentation](https://ena-docs.readthedocs.io/en/latest/submit/general-guide/programmatic.html)
- [ENA Umbrella Projects Guide](https://ena-docs.readthedocs.io/en/latest/submit/project/umbrella.html)
- [ENA Webin Portal](https://www.ebi.ac.uk/ena/submit/webin/login)
