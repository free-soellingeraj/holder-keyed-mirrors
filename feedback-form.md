# Feedback form: specification

This file specifies the feedback form that a maintainer creates by hand in an online form tool. Its address goes into README.md and CONTRIBUTING.md in place of `{{FORM_URL}}`. Build the form exactly as below, then check it once by submitting a test response while signed out.

## Title

Feedback on "Holder-keyed data mirrors for AI assistants"

## Introduction

Show this text under the title:

> This form collects comments on a reference architecture under public review. It is a design, and it does not describe any system as it runs today.
>
> Write about anything, large or small: a flaw, a question, a missing case, a clearer way to say something. You don't need to sign in, and you don't need to give your name. If you would like a reply or updates, you can leave an email address below. We use it only for what you ask for.

## Questions

### 1. Which section is your comment about?

- **Type:** dropdown
- **Required:** no
- **Options,** in this order:

<!-- section-options:start -->
- 1. Status and scope
- 2. The idea in one paragraph
- 3. Glossary
- 4. What opens what
- 5. Eight scenarios
- 5.1 First run
- 5.2 Open the dashboard
- 5.3 Connect an AI assistant
- 5.4 An AI assistant asks
- 5.5 Arrivals while nobody is calling
- 5.6 Debug access
- 5.7 A lost device
- 5.8 Disconnect, sign out, delete
- 6. Lifecycle of each credential
- 7. Platform independence
- 8. Performance
- 9. Verification levels
- 10. Limits
- 11. Open questions we want input on
- 12. Related work
- The whole design
- Something else
<!-- section-options:end -->

The numbered options must match the numbered headings in architecture.md. `build.sh` checks this and fails if they differ. When it fails, update this list and then the live form.

### 2. Your comment

- **Type:** paragraph
- **Required:** yes
- **Help text:** "As long or as short as you like."

### 3. Your email address, if you'd like a reply

- **Type:** short answer
- **Required:** no
- **Validation:** text is an email address
- **Help text:** "Optional. Leave it blank to stay anonymous."

### 4. Stay in touch

- **Type:** checkboxes
- **Required:** no
- **Options:**
  - Send me updates on this design
  - Invite me when it's ready
- **Help text, the consent sentence:** "If you tick a box, we will use the email address above only for what you ticked, and every message we send will tell you how to stop. If the email box is blank, we can't act on a ticked box."

## Settings

- **Sign-in:** not required. Don't restrict the form to any organization, and don't limit people to one response, because that needs sign-in.
- **Collect email addresses:** don't collect them automatically. The only address the form gets is the one a person types into question 3.
- **Editing after submit:** off.
- **Responses:** send them to a new spreadsheet, shared only with the maintainers.
- **Confirmation message:** "Thank you. Your comment has been recorded."
