# Instructions for AI assistants editing this repository

This repository is a reference architecture under public review. [architecture.md](architecture.md) is the single source of truth. Everything under `build/` is generated from it by `./build.sh`, and the online documents are copied from it. People read every change on the web, in an online document and as a .docx, so each change must stay plain, neutral and correct.

Follow every rule below. If a request conflicts with one, say so and ask before going further.

## 1. Stay vendor-neutral

Name no company, product, brand, cloud service, operating system, device or AI assistant anywhere, except in the "Sponsored by" section of README.md. Describe each thing by its role instead:

| For a product that is... | write |
|---|---|
| the service's own apps and pages | "the service", "the companion app", "the web dashboard", "settings" |
| an AI assistant | "the user's AI assistant", "any MCP client" |
| an email, chat or calendar provider | "source accounts", "email", "chat apps" |
| a database or file store | "the database", "object storage" |
| a cloud key service | "a managed KMS backed by an HSM", "the KMS's audit log" |
| a confidential-computing product | "a hardware-attested confidential VM" |
| a build-signing or transparency service | "signed builds recorded in a public transparency log" |
| an index type from one database | describe the structure, for example "an inverted index over keyed tags" |
| an operating system's key store | "the OS keystore", "a hardware-backed keystore (TPM or secure enclave)" |
| a platform's random number interface | "the OS random number generator" |

Open standards and protocols keep their names: AES-256-GCM, AES key wrap, HKDF-SHA256, HMAC-SHA256, X25519, HPKE, RSA-OAEP, OAuth 2.1, PKCE, MCP, SLSA, TPM. Standards bodies keep their names too.

Before you finish, search your change, case-insensitively, for every product and company name you can think of, and remove any you find.

## 2. Describe the design only

Write about the target design, never about a system as it runs.

- No "today", "currently" or "as built", and no list of current gaps.
- No file names, code paths, commit hashes, route names or table names from any codebase. Standard protocol terms, such as "the token endpoint", are fine.
- No build plan, task numbers or pull-request counts.
- No decisions addressed to a person, and no people's names.

## 3. Don't overstate

Never write "end-to-end encrypted", "zero-knowledge", "nobody but you can read it", or any claim to be first. Section 10 of architecture.md says what the design does not protect against. Keep every "Where it's weak" list. Remove a weakness only when the design changes to close it, and say so in your pull request.

## 4. Keep diagrams in Mermaid

- Every diagram is a fenced `mermaid` block in architecture.md. Don't add images of diagrams.
- Give each one an `accTitle:` and an `accDescr:` line. `accDescr` becomes the image's alt text in the .docx.
- Inside message and label text, use no semicolons and no `#`. Mermaid reads a semicolon as the end of a statement, and `#` as the start of an entity code.
- Break long lines with `<br/>`, at about 45 characters.
- Mermaid clips a note's text when it is wider than the note, and a note over one participant is narrow. Span at least two participants (`Note over A,B`), let a long note span all of them, and look at the rendered PNG under `build/` to check.
- Sequence diagrams use `autonumber`. Each "On screen" note refers to those step numbers, so renumber the notes when you add or remove a step.

## 5. Cite standards by RFC number

Write "HPKE (RFC 9180)", not just "HPKE". Where there is no RFC, cite the defining document, such as NIST SP 800-38D or an Internet-Draft's name. Add each new standard to the table "Standards this design uses" in section 12.

## 6. One topic per pull request

A wording fix and a design change are two pull requests. So are two unrelated design changes.

## 7. Run the build before proposing

Run `./build.sh`. It must end with `rendered N diagrams` and the .docx path, with no errors. If a diagram fails, fix the Mermaid, not the build. Commit the regenerated `build/` directory with your change.

The build also checks that the section list in [feedback-form.md](feedback-form.md) matches the numbered headings in architecture.md. If you add, remove or rename a numbered section, update that list too.

## 8. Write plainly

- Plain, calm, specific prose. Short sentences. No hype.
- Define each term the first time it is used.
- A security engineer who has never heard of the sponsor must be able to follow every section.
- Keep cross-references ("section 9", "5.3") correct when you move or add anything.
