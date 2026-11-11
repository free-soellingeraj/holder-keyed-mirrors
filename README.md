# Holder-keyed data mirrors for AI assistants: a reference architecture

> This is a design under public review. It does not describe any system as it runs today.

People increasingly connect AI assistants to their email, messages, calendars and files. A common way to do that is a service that copies data from each of a person's accounts into one searchable store, and answers the assistant's questions from that store. The store then holds years of a person's correspondence in readable form, one storage breach, database dump, stolen backup or curious operator away from exposure. Encrypting the disks does not help against any of these, because the service holds that key too.

This design keeps each account's data under one key that the person's own computer creates. The service stores a separate locked copy of that key for each thing the person has let in: their computer, each AI assistant, each browser session, each script. Each copy opens only with a secret that its holder brings with every request. The server opens the key for one request and then forgets it, so revoking access is deleting one row. Support staff can look only after the person turns that on, through a hardware security module that logs every use. The design also says plainly what it does not protect against.

## How to read it

Every format is generated from the Markdown in this repository. If two formats disagree, the Markdown is right.

- **This repository.** Start with [architecture.md](architecture.md). The diagrams are Mermaid and render on the page.
- **A shared online document, open for comments:** {{GOOGLE_DOC_URL}}
- **A Word file:** [build/holder-keyed-mirrors.docx](build/holder-keyed-mirrors.docx), built from the Markdown by [build.sh](build.sh).
- **An assistant-readable document, to read and question with an AI assistant:** {{CLAUDE_DOC_URL}}

## How to contribute

- **Issues and pull requests** on this repository. [CONTRIBUTING.md](CONTRIBUTING.md) explains the rules and how to build.
- **Comments** in either online document.
- **Mark up the .docx** with comments or tracked changes, and send it back to {{CONTACT}}.
- **Anonymous comments, and sign-up for updates,** through the feedback form: {{FORM_URL}}. You don't need to sign in, and an email address is optional.

## Using your AI assistant to propose a change

1. Download or clone this repository, and open it with your AI assistant.
2. Tell it: "Read AGENTS.md and follow it. Then propose this change to architecture.md: *your change*. Keep it to one topic."
3. Ask it to run `./build.sh` and to fix any diagram that fails to render.
4. Read the change yourself before you send it. Then open a pull request, or send the changed file to {{CONTACT}}.

[AGENTS.md](AGENTS.md) holds the rules your assistant needs: stay vendor-neutral, describe the design only, keep diagrams in Mermaid, and cite standards by RFC number.

## Sponsored by

<img src="assets/matterboard-horizontal-light-h64.png" alt="MatterBoard" width="365" height="64">

MatterBoard sponsors this work. The architecture itself names no company or product.

## License

Text under [CC BY 4.0](LICENSE) (draft, to confirm).
