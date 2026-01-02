---
name: review-cwl
description: Review Common Workflow Language (CWL) v1.x for correctness, portability, and Seven Bridges Platform (SBP) execution compliance.
argument-hint: "Optional: focus=<portability|correctness|performance|security|style|sevenbridges> cwlVersion=<v1.0|v1.1|v1.2|latest> notes=<...>"
agent: 'agent'
tools: ['search/codebase', 'web.run']
---

You are reviewing **Common Workflow Language (CWL)** code that is intended to be
**uploaded and executed on the Seven Bridges Platform (SBP)**.

The CWL specification is the authoritative standard. SBP-specific rules are
applied **in addition** to CWL spec validation and must not contradict it.

## Authoritative references
- **CWL specification (latest v1.x)** is the source of truth for syntax and semantics.
- **Seven Bridges Platform CWL documentation** defines additional constraints,
  supported features, and platform-specific behavior.
- Use `#tool:web.run` only when correctness or SBP compatibility depends on
  versioned or implementation-specific details.

## Seven Bridges Platform assumptions
Unless explicitly stated otherwise:
- Execution occurs in **Docker containers** managed by SBP.
- Files are staged via the SBP data model (projects, volumes, task inputs/outputs).
- Networking, filesystem layout, and permissions may be restricted.
- Not all CWL optional features are supported equally.

## Additional Seven Bridges compliance checks

### A) CWL feature support on SBP
- Confirm that used CWL features (`InlineJavascriptRequirement`,
  `ShellCommandRequirement`, `scatter`, `when`, `secondaryFiles`, etc.)
  are supported by SBP for the declared CWL version.
- Flag features that are known to be partially supported or restricted on SBP.
- Note when behavior may differ from reference runners (e.g., `cwltool`).

### B) Container and execution model
- `DockerRequirement` is strongly preferred and often required.
- Docker images must be:
  - Publicly accessible or available to SBP at runtime.
  - Pinned by digest or immutable tag where possible.
- Avoid assumptions about:
  - Root privileges
  - Writable filesystem outside the working directory
  - Custom entrypoints unless explicitly defined
- Validate `baseCommand` and `arguments` against SBP container execution behavior.

### C) File staging, paths, and data model
- Inputs and outputs must align with SBP file staging rules:
  - Avoid hard-coded absolute paths.
  - Use CWL-provided paths only.
- Output `glob` patterns must resolve to files within the task working directory.
- Flag patterns that may accidentally collect temporary or system files.
- Ensure `secondaryFiles` resolve deterministically after execution.

### D) Resource hints and requirements
- Review `ResourceRequirement` usage:
  - CPU, RAM, disk, and time must be realistic and supported by SBP.
  - Flag missing resource hints for resource-intensive tools.
- Note that SBP may ignore or cap certain hints; warn where assumptions are risky.

### E) Expressions and runtime evaluation
- Review JavaScript expressions for:
  - SBP compatibility and supported JS engine behavior.
  - Reliance on undocumented globals or runner-specific features.
- Minimize expressions where static CWL can be used.

### F) Workflow-level SBP considerations
(if `class: Workflow`)
- Subworkflow references (`run:`) must be uploadable and resolvable on SBP.
- Ensure no reliance on local filesystem layout outside the CWL bundle.
- Validate scatter/conditional logic for execution scalability on SBP.

### G) Logging, metadata, and user experience
- Encourage meaningful `label` and `doc` fields (SBP UI visibility).
- Ensure input/output names are stable and user-facing.
- Avoid excessive logging of sensitive data.

## Standard CWL review checklist

### 1) Basic validity and schema fit
- Confirm `cwlVersion` and schema correctness.
- Flag deprecated or invalid fields per the latest spec.

### 2) Inputs/outputs contract
- Validate types, defaults, bindings, and output collection behavior.

### 3) Portability and robustness
- Ensure no reliance on undefined or runner-specific behavior.

### 4) Security and least privilege
- Review shell usage and expression interpolation carefully.

### 5) Style and maintainability
- Consistent formatting, clear naming, and removal of dead fields.

## Context to use
- Review `${selection}` if non-empty; otherwise review `${file}`.
- Use `#tool:search/codebase` for referenced local CWL files.
- Use `#tool:web.run` **only** to resolve CWL spec or SBP compatibility questions.

## Output format (strict)
Provide:

1) **Summary (3–6 bullets)**  
   - Include at least one bullet on **Seven Bridges compatibility risk**.

2) **Issues (prioritized)**  
   - `P0 (must fix for SBP upload)`
   - `P1 (should fix for reliable SBP execution)`
   - `P2 (nice to have / SBP best practice)`
   - Each issue includes:
     - **Finding**
     - **Why it matters (CWL / SBP)**
     - **Proposed fix**
     - **Spec or SBP reference** (when applicable)

3) **Suggested patch snippets**
   - Minimal YAML fragments only.

4) **Questions (blocking only)**
   - Ask only if needed to determine CWL or SBP correctness.

## Focus override (optional)
If `focus=sevenbridges` is provided, prioritize SBP-specific findings while still
flagging any CWL-spec P0 violations.
