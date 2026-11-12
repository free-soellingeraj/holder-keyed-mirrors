# Contributing

Thank you for reading the design. Every kind of comment helps, from a typo to a flaw in the cryptography.

## Ways to take part

- **[Open an issue](https://github.com/free-soellingeraj/holder-keyed-mirrors/issues)** for a question, a weakness you found, or a change you'd like to discuss before writing it.
- **[Open a pull request](https://github.com/free-soellingeraj/holder-keyed-mirrors/pulls)** with a change to [architecture.md](architecture.md). The rules below apply.
- **Comment in either online document.** The links are in [README.md](README.md).
- **Mark up the .docx** with comments or tracked changes, and send it back in [a new GitHub issue](https://github.com/free-soellingeraj/holder-keyed-mirrors/issues/new) on this repository, with the file attached.

Comments in the documents, on the .docx and through the form are carried back into the Markdown by the maintainers, one topic at a time, as pull requests.

## Rules for changes

These are the same rules [AGENTS.md](AGENTS.md) gives to AI assistants. They apply whether you write the change yourself or with an assistant.

1. **Vendor-neutral.** Don't name any company, product, cloud service, operating system, device or AI assistant outside the README's "Sponsored by" section. Say what the thing does instead: "the database", "object storage", "a managed KMS backed by an HSM", "the OS keystore", "any MCP client". AGENTS.md has the full list of replacements. Open standards keep their names.
2. **Design only.** Describe the target design. Don't describe any running system, and don't include file names, code paths, commit hashes, route names, build plans, decisions addressed to a person, or people's names.
3. **Don't overstate.** Avoid "end-to-end encrypted", "zero-knowledge", "nobody but you can read it", and claims to be first. Keep every "Where it's weak" list honest.
4. **Diagrams in Mermaid.** Edit the fenced `mermaid` blocks. Don't use semicolons or `#` inside message or label text, because Mermaid treats them as syntax. Keep the `accTitle` and `accDescr` lines.
5. **Cite standards by RFC number,** and add new ones to the table at the end of section 12.
6. **One topic per pull request.**
7. **Build before you propose,** and commit the regenerated `build/` directory with your change.

If your change adds, removes or renames a numbered section, also update the section list in [feedback-form.md](feedback-form.md). The build fails until the two match.

## Building

The build turns the Markdown into the .docx. It needs two tools:

- **Mermaid CLI** (`mmdc`), which renders the diagrams: `npm install --global @mermaid-js/mermaid-cli`. It downloads a headless browser on first install.
- **pandoc**, version 3 or later, from <https://pandoc.org/installing.html> or your system's package manager.

Then, from the repository root:

```sh
./build.sh
```

It writes `build/architecture.md` (the Markdown with each diagram replaced by a PNG), the PNGs, and `build/holder-keyed-mirrors.docx`. It ends by printing how many diagrams it rendered and the size of the .docx. If a diagram fails to parse, `mmdc` names it and the build stops. Never edit files under `build/` by hand: the script deletes and rewrites that directory each time.

Every push and pull request runs the same build automatically, and the .docx is attached to the run as a downloadable artifact: see <https://github.com/free-soellingeraj/holder-keyed-mirrors/actions>.

## Review

A maintainer reads each pull request against the rules above, checks that the build passes, and either merges it, asks for changes, or explains why not.
