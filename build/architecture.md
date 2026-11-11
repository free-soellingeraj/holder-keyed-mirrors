# Holder-keyed data mirrors for AI assistants: a reference architecture

> This is a design under public review. It does not describe any system as it runs today.

Draft 0.1, 11 November 2026.

## 1. Status and scope

This document describes a design for a service that keeps a searchable copy of a person's messages, contacts, calendars and files, so that the AI assistants the person chooses can read it. We call that copy a **mirror**, and the accounts it is copied from **source accounts**: email, calendars, contacts, file stores and chat apps.

The design has one narrow goal. Content at rest on the service opens only through a key that the person's own computer creates, and through copies of that key that each authorized caller holds the secret for. We call each such caller a **holder**: the companion app on the person's computer, a connected AI assistant, a web dashboard session, a personal access token, and support staff while the person has turned on Debug access, a setting that gives support time-limited access. AI assistants connect through the Model Context Protocol (MCP), an open protocol that lets an assistant call tools and read data on a person's behalf.

It is a draft for public review. Every part is open to change, and section 11 lists the questions we most want help with.

**In scope:** how the account key is born, kept, moved, used and retired; how each kind of holder gains and loses access; how data that arrives while no holder is calling is protected; how support can be given time-limited access; and how someone outside the service could check these claims.

**Out of scope:** how the service signs in to source accounts; what an AI assistant does with what it reads; interface design beyond what each step needs; and pricing.

### Threat model in plain words

**It protects against:**

- **A storage breach.** Someone copies the disks, the database files or the object storage. They get ciphertext, locked copies of the key and hashes of tokens. None of these opens anything without a holder's token.
- **A database dump.** A leaked export, an injection bug that reads whole tables, or an operator running queries. The tables hold the same ciphertext, keyed tags, locked copies and token hashes.
- **A stolen backup.** Backups hold what the database holds.
- **Operator curiosity.** A member of staff who wants to look at an account cannot, unless the person has turned on Debug access. Even then, each look goes through a key held in a hardware security module (HSM), inside a managed key management service (KMS), and each use is written to the KMS's audit log, which the service's own code does not write.

**It does not protect against:**

- **A request in progress, before attestation.** To answer a holder, the server unwraps the account key and decrypts the rows in the answer, in memory. Until the server runs as an attested build (level 3 in section 9), a compromised server, or a malicious change to the server's code, could copy the key or the plaintext during a request.
- **The AI assistant's own copy.** Whatever an assistant reads is then held by that assistant and its provider, under their terms. This design ends where the answer leaves the service.

Section 10 lists the other limits.

## 2. The idea in one paragraph

Each account's content is encrypted under one random symmetric key, the **account key**, which is born on the person's own computer and never stored on the server in usable form. Instead, the server keeps one **locked copy** of the account key for each holder, wrapped under a key derived from that holder's **unlock secret**. The secret travels only inside the token the holder already presents, and the server stores only a hash of the token's lookup part, never the secret. When a holder calls, the server derives the wrapping key, unwraps the account key in memory for that one request, answers, and forgets the key. Revoking a holder deletes one row. Data that arrives while no holder is calling is sealed to the account's public key and opened on the next call. Support staff can open an account only while the person has turned on Debug access, through one more copy wrapped to a key that never leaves an HSM, and every such use is logged.

## 3. Glossary

Every key and credential in the design is listed here. Only two are lasting keypairs: the account's X25519 pair and the support key. A new device also makes a one-time X25519 pair, used once to receive the account key and then thrown away. The account key is a symmetric key. Everything else is a **bearer secret**: whoever presents it is let in, so what matters is where it is kept, how long it lives and how fast it can be revoked.

**How tokens are built.** Every token in this design has two parts: a **lookup part**, which the server hashes with SHA-256 to find the holder's row, and the holder's **unlock secret**. The server stores the hash of the lookup part and never stores the secret. Both parts are long random values, so a plain hash is enough: there is nothing to guess.

### Keys

| Name | Kind | Holder | Where it is kept | Lifetime |
|---|---|---|---|---|
| Account key | AES-256 symmetric key, 256 random bits | The account. The companion app holds the original. | The OS keystore on the person's computer. On the server, only as locked copies. | The life of the account. Rotation is an open question. |
| Derived keys | Content keys (AES-256-GCM) and tag keys (HMAC-SHA256), derived from the account key with the HKDF-SHA256 key derivation function (RFC 5869) | Made inside a request | Never stored | As long as the account key |
| Locked copy | The account key, wrapped with AES key wrap with padding (RFC 5649) | The server, one per holder | A database row: holder, created, expires | As long as its holder |
| Unlock secret | 256-bit random secret. HKDF-SHA256 turns it into the key that wraps the locked copy. | Each holder, inside its token | Never stored on the server | As long as the token that carries it |
| Account keypair | X25519 elliptic-curve keypair (RFC 7748), used with Hybrid Public Key Encryption, HPKE (RFC 9180) | Public half: the server, in the clear. Private half: wrapped under the account key. | The database | As long as the account key |
| One-time enrollment keypair | X25519 keypair | A new device, while it waits for approval | The new device's memory | Minutes. Discarded once the device has its own locked copy. |
| Support key | RSA-OAEP keypair (RFC 8017) inside an HSM | A managed KMS backed by an HSM. The private half never leaves it. | The KMS. Every use is written to the KMS's audit log. | Long-lived. Key versions rotate inside the KMS. |
| Support copy | The account key, encrypted to the support key's public half | The server, only while Debug access is on | A database row with its end time | Until the end time, or until the person turns Debug access off |

### Credentials a holder presents or receives

| Name | Kind | Holder | Where it is kept | Lifetime |
|---|---|---|---|---|
| Device token | Bearer token: lookup part plus the device's unlock secret | The companion app | The OS keystore, hardware-backed where the computer has one. The server keeps the hash. | Until the device signs out or is removed |
| Session cookie | Bearer token: lookup part plus the session's unlock secret, in an HttpOnly, Secure, SameSite cookie (RFC 6265) | The person's browser | The browser's cookie store. The server keeps the hash. | Until sign-out, removal of the device that opened it, or a fixed maximum age |
| Connect code | One-time code: lookup part plus a one-time secret | The companion app, then the browser's URL fragment | The server keeps the hash and a one-time wrap of the account key | 60 seconds, single use |
| Authorization code | OAuth 2.1 authorization code bound to a Proof Key for Code Exchange (PKCE) challenge (RFC 7636), with a one-time secret | Passes through the browser to the AI assistant | The server keeps the hash and a one-time wrap of the account key | A few minutes, single use |
| Access token | OAuth 2.1 bearer access token (RFC 6750): lookup part plus the assistant's unlock secret | The AI assistant (any MCP client) | The client's own storage. The server keeps the hash. | Short. It expires and is renewed with the refresh token. |
| Refresh token | OAuth 2.1 refresh token: lookup part plus the assistant's unlock secret | The AI assistant | The client's own storage. The server keeps the hash. | Single use. Each use returns a new one. |
| Personal access token | Bearer token: lookup part plus its own unlock secret, with scopes and an expiry | A REST client or script the person runs | Wherever the person keeps it. The server keeps the hash. | Until its expiry, or until the person deletes it |
| Device approval code | A short code computed from a new device's one-time public key | Shown on the new device and on the approval screen | Not stored. Either side recomputes it from the public key. | Until the request is approved, denied or times out |
| Source account tokens | OAuth refresh tokens the service holds for the person's source accounts | The service | The database, wrapped under the account key | Until the person disconnects that source |

## 4. What opens what

![Five kinds of holder each present a token. Four carry an unlock secret that opens that holder's own locked copy of the account key. Support can reach the account key only through a support copy, which exists only while Debug access is on. The account key opens content, the search and identity tags, the X25519 private key and the source account tokens.](./architecture-1.png "What opens what")

Each holder can reach the account key only through its own locked copy, so revoking one holder is deleting one row. Support has no copy at all until the person turns on Debug access. Dashed lines exist only while Debug access is on.

## 5. Eight scenarios

Eight everyday moments, in the order a person meets them. Each has a sequence diagram, what the person sees on screen, and three short notes: in plain words, why this design, and where it's weak. The diagrams number every step, including the steps the server takes on its own. Notes in the diagrams are not numbered.

### 5.1 First run

The companion app makes every key. The server receives only locked material and a public key.

![The companion app signs in and receives the lookup part of a device token. It then creates the account key, the account keypair and its own unlock secret, keeps them in the OS keystore, and sends the server only its locked copy, the public key and the wrapped private key.](./architecture-2.png "First run")

**On screen**

- **Step 1, the companion app's sign-in window.** The person clicks Continue with their sign-in provider, or asks for an emailed code, and picks their account. That is the only thing they do. The app makes every key by itself.

**In plain words.** Everything the service keeps for you is locked with one key. When you first set up the companion app, your computer makes that key and keeps it in its own safe. It puts a copy of the key in a lockbox that opens only with a password your computer knows, and hands the lockbox to the service. The service holds the box but can't open it.

**Why this design.** The key is born where the person is, not on the server. The server receives only locked copies and a public key, so even a server that was broken into from day one has nothing at rest that it can open. The public half of the account keypair lets the server accept new data later without being able to read it.

**Where it's weak.**

- Whoever controls the computer at setup controls the key. Malware on it can read the key.
- An OS keystore protects the key at rest, but only a hardware-backed keystore with a presence check, such as a fingerprint or a PIN, stops other software running as the same user. Not every computer has one.
- The server cannot tell whether the key was made with good randomness.

### 5.2 Open the dashboard

The companion app vouches for the browser, so the person never types a password into the web dashboard.

![The companion app asks for a one-time connect code. The server stores only the code's hash and a one-time wrap of the account key. The browser redeems the code within 60 seconds, and only then does the server make the session's own unlock secret and locked copy, deleting the code row.](./architecture-3.png "Open the dashboard")

**On screen**

- **Step 1, the companion app's menu.** The person chooses Open dashboard.
- **Step 10, the browser.** The web dashboard opens, already signed in. There is no password and no code to type.

**If the 60 seconds run out**

- **Opened late.** The browser presents the code after 60 seconds. The server refuses it and deletes its row. The page says the link has expired and asks the person to choose Open dashboard again for a new code.
- **Reused or reloaded.** The code has already been redeemed, so the server refuses it as already used. If this browser already holds the session from that code, the session still works. The page also removes the code from the address bar as soon as it reads it, so an ordinary reload never presents it again.
- **Copied to another browser.** After 60 seconds, the other browser is refused. Inside the 60 seconds, whichever browser redeems the code first gets the session, and the other is refused as already used.
- **Never redeemed.** A cleanup sweep deletes the code's row, and with it the code's one-time wrap.

The session's locked copy is created at redeem time, not when the code is minted, so an expired code never leaves an orphaned copy. The only key material a code leaves behind is its one-time wrap, which lives in the code's own row and is deleted with it.

**In plain words.** Your computer writes a permission slip that works once and lasts one minute. The browser hands in the slip and gets its own lockbox and password, kept in a cookie that the web page itself can't read.

**Why this design.** The browser never needs the person's sign-in password. The code lives 60 seconds, works once, and travels in the URL fragment, the part of a web address after the hash sign, which browsers do not send to servers, so it never reaches server logs. The session's secret lives only in an HttpOnly cookie, out of reach of page scripts, and never in browser storage that page scripts can read. Making the session's copy at redeem time means an unused code leaves nothing behind.

**Where it's weak.**

- Anyone at the person's unlocked computer can open a dashboard session, and that session can do anything the device can.
- A code that leaks inside its 60 seconds gives a session to whoever redeems it first.
- The page script reads the code from the fragment, so a script injected into the dashboard could read it too.
- During those 60 seconds, the code and its row together open the account key.

### 5.3 Connect an AI assistant

Any MCP client can connect, through OAuth 2.1 with PKCE (RFC 7636) and without registering in advance. The client identifies itself the way the MCP authorization specification asks: with a client ID metadata document, which the specification prefers, or with dynamic client registration (RFC 7591), which it keeps for backward compatibility. Either way, the server compares the redirect address with the registered one exactly, character for character. Because any client can register, the consent page is the main gate: it is the one point where a person decides that a new holder should exist. So every new connection sends a notice to the account's email address, naming the client and saying how to remove it.

The assistant's locked copy is made at the token exchange, not at consent, for the same reason as in 5.2. Until then, the authorization code is a one-time holder of its own.

![An MCP client registers and sends the person to the consent page. On approval the server mints a one-time authorization code with its own wrap of the account key. At the token exchange the server checks PKCE, makes the assistant's unlock secret and locked copy, notifies the account email and returns tokens carrying the secret. Later a refresh spends the refresh token and re-wraps the copy under a new secret.](./architecture-4.png "Connect an AI assistant")

**On screen**

- **Step 1, the assistant's connector settings.** The person adds the service as a connector, by its address, and presses Connect. Each assistant words this differently.
- **Step 3, the service's consent page.** It shows which client is asking, with its registered name and redirect address, what it may read, that access is read-only, and that it gets its own key the person can remove at any time in settings. The person can name the connection, then clicks Approve, or Cancel.
- **Step 10, the person's email.** A message says a new assistant was connected, names the client and the time, and links to the settings page that removes it.

**Refresh.** The refresh token also carries the holder's unlock secret, so a refresh can re-wrap the copy under a new secret. Access tokens expire. Refresh tokens are single use: each refresh spends the old one and returns a new pair, and the old access token stops working at once, because its secret no longer opens the copy. Following the OAuth security best current practice (RFC 9700), a refresh token presented a second time is treated as stolen: the server refuses it and deletes the holder's copy, and the assistant must be connected again.

A script or REST client that cannot run OAuth uses a personal access token instead (section 6).

**In plain words.** You say yes, this assistant may help me. The service then makes the assistant its own lockbox with a fresh password, and gives that password only to the assistant. You get an email, so you know it happened.

**Why this design.** Consent happens inside a session that already holds the key, so making the new copy needs nothing more from the person. Each assistant can be cut off on its own. PKCE and the exact redirect match stop a stolen authorization code from being used anywhere else. The email notice turns a silent new holder into a visible one.

**Where it's weak.**

- Anyone who can click Approve in the person's signed-in browser can add an assistant, so a hijacked session becomes a new key holder. The email notice is the safety net, and it works only if the person reads it.
- The refresh token carries the secret, so a leaked refresh token opens the copy until it is spent or the holder is removed.
- Dynamic registration lets any client choose its own name, so the name on the consent page is a claim, not a proof. The redirect address is the more reliable thing to show.
- For the few minutes between consent and the token exchange, the authorization code and its row together open the account key.

### 5.4 An AI assistant asks

Only the assistant and the server take part. The access token the assistant presents was made when the person connected it (5.3), and the diagram repeats where it came from.

**How search works without plaintext.** Every three-character fragment (trigram) of message text, senders, chat names and participants becomes a 64-bit tag: HMAC-SHA256 of the fragment under a tag key derived from the account key, cut to 64 bits. The tags are stored in an inverted index, which maps each tag to the rows that carry it. A query is turned into the fragments that any match must contain. The server looks up the rows that carry all those tags, decrypts only those candidates, and runs the real query on the plaintext to drop false matches. A pattern with no fixed fragments falls back to a bounded scan. Handles, addresses and names are matched the same way, with keyed identity tags, so grouping messages by person still works.

![Once, at connection time, the assistant exchanged its authorization code for tokens carrying its unlock secret. For every question it sends an MCP call with its access token. The server finds the holder by hash, unwraps the account key in memory, looks up keyed tags, decrypts only the candidate rows, checks them, answers and forgets the key.](./architecture-5.png "An AI assistant asks")

**On screen**

- **Step 3, the assistant's own chat.** The person asks a question, for example what a colleague said about a lease renewal. The assistant decides when to call the service. Nothing on the service's side needs a click.

**In plain words.** The assistant knocks with its own password. The service uses it to open the assistant's lockbox, takes out the key, reads only the pages the assistant asked for, hands them over, and puts the key back. Nobody writes anything down.

**Why this design.** It costs one indexed lookup and microseconds of cryptography, with no call to another service on the way. Only the rows in the answer are decrypted, the key lives for one request, and search uses an inverted index over keyed tags, so answers stay fast (section 8).

**Where it's weak.**

- During the request the server holds the key and the plaintext in memory, so a compromised server or a malicious code change could copy them, until the attested server of level 3 (section 9).
- A stolen access token opens the copy until it expires or the holder is removed.
- Keyed tags show which rows share a fragment, though not what the fragment is.
- The assistant's provider sees everything the assistant asked for and received.

### 5.5 Arrivals while nobody is calling

Some data reaches the service while no holder is calling: forwarded email, messages that chat apps push to the service, and change events from source accounts. The server has no account key at those moments. So it seals each arrival to the account's public key with HPKE (RFC 9180), and the next holder's call opens it.

Pulling new data from a source account is different. The source account's token is wrapped under the account key, so a pull runs only inside a holder's call, or on the companion app itself.

![A new message arrives while no holder is calling. The server seals it to the account's public key with HPKE and stores only the sealed form. On the next authorized call, the server unwraps the account key and then the private key, opens the sealed arrivals, builds their tags, encrypts them under the account key and deletes the sealed copies.](./architecture-6.png "Arrivals while nobody is calling")

**On screen.** Nothing. Arrivals are sealed and opened without the person doing anything.

**In plain words.** When a letter arrives and nobody is home, the service drops it through a mail slot that locks behind it. Only someone with a key can open the mailbox later.

**Why this design.** New data keeps arriving without the server ever holding the key. Anyone can seal, and only a holder's call can open. The public half of a keypair is safe to keep anywhere, and HPKE is a published standard rather than an invented scheme.

**Where it's weak.**

- Anything that must read new data right away, such as sorting, filing or alerts, has to wait for a holder to call (section 11).
- The server sees each arrival in the clear for the moment it arrives, before sealing it.
- Sizes and arrival times stay visible.

### 5.6 Debug access

The person turns it on. Support cannot.

![The person turns on Debug access from settings. The server encrypts the account key to the support key's public half and stores that support copy with an end time. A support request makes the KMS decrypt the copy, which the KMS's audit log records, and the use appears in the person's list. Turning it off, or reaching the end time, deletes the support copy.](./architecture-7.png "Debug access")

**On screen**

- **Step 1, settings, Debug access.** A short text says that support can open the mirror to fix a problem and that every use is listed here. The person picks an end time, can add a reason such as a ticket number, and clicks Turn on. Support has no way in until then.
- **Step 7, settings, who looked.** A banner says Debug access is on until the end time. Below it, one line per use: when support opened the mirror and for how long. Each line comes from the KMS's audit log of the support key.
- **Step 8, the same page.** Turn off now deletes the support copy at once.

**In plain words.** If something breaks, you can hand the service's helpers a spare key, in a box that only one special locked machine can open. The spare key expires on its own, and you see every time they use it.

**Why this design.** Support access is the person's choice: time-limited, revocable, and logged by the KMS rather than by the service's own code. The support key's private half never leaves the HSM, so no staff laptop ever holds it.

**Where it's weak.**

- While it is on, a support person with the right role can read the mirror. A compromised staff account during that time has the same access, which two-step sign-in reduces.
- The KMS does not know about the end time. The server enforces it by deleting the support copy, so a bug there would extend access.
- A backup taken while Debug access was on holds the support copy until that backup expires.

### 5.7 A lost device

Any device the person still has can open the dashboard, cut off a lost device and vouch for a new one. The new device shows a code, and the approval screen shows the same code. The person approves only if they match. The code is computed from the one-time public key the new device sent, so a different device asking at the same moment would show a different code.

![From the dashboard on a device the person still has, they remove the lost device, which deletes its copy and revokes its tokens. A new device signs in and sends a one-time public key, and shows a code computed from it. The dashboard shows the same code. After the person approves, the server seals the account key to the new device's one-time key. The new device opens it and makes its own unlock secret and locked copy.](./architecture-8.png "A lost device")

**On screen**

- **Step 1, settings, Devices.** A list of the person's devices with when each was last seen. The person clicks Remove next to the lost one. Its copy of the key is deleted, so it can never open the mirror again.
- **Step 3, the new device's companion app.** It says the account already has a key and asks the person to approve this device from the dashboard on a device they still have. It shows a code, such as 4F7K-29QD, and waits.
- **Steps 4 and 5, settings, approve a new device.** The page says a new device asks to join, gives its name, asks the person to check that the code matches the one on that device, and shows the code with Deny and Approve. The person approves only if the codes match.

**In plain words.** If you lose your computer, you throw away its lockbox from the dashboard. A new computer gets its own lockbox once you say yes from somewhere you're already signed in, and only if both screens show the same code.

**Why this design.** Any device the person still holds can cut off the lost one and vouch for a new one. The matching code ties the approval to one specific device. Because the service keeps no recovery key, there is no back door for anyone, the service included.

**Where it's weak.**

- If every holder is lost, the mirror can't be read. It refills from the original sources, but anything that exists only on the service, such as notes the person wrote there, is gone if it is stored under the key.
- A person with one device who loses it has no dashboard session left to approve from. Connected assistants still hold copies, but approving a device needs a person at the dashboard, so this is the same as losing every holder.
- A thief with the unlocked device can act until it is removed.
- The approval screen is where a trick would be tried: a person who approves without comparing the codes lets in whichever device asked.
- The server computes the code the dashboard shows, so the code protects against another device, not against a compromised server.

### 5.8 Disconnect, sign out, delete

Revoking access becomes deleting a row.

![Disconnecting an assistant or deleting a personal access token deletes that holder's locked copy and revokes its tokens. Signing out on the companion app revokes the device token and the sessions it opened, deletes their copies, and removes the token and key from the OS keystore. Deleting the account deletes every copy and every row.](./architecture-9.png "Disconnect, sign out, delete")

**On screen**

- **Step 1, settings, your assistants.** One row per connection, with the name the person gave it, and a Disconnect button. Personal access tokens are listed the same way, each with a Delete button.
- **Step 3, the companion app's menu.** The person chooses Sign out. If this is the only device that holds the key, the app says so before it signs out.
- **Step 7, settings, delete account.** A Delete account button, then a confirmation. Every copy of the key and every row goes.

**In plain words.** Taking a helper's access away means throwing its lockbox in the shredder. Deleting your account shreds every lockbox, so the locked diaries left behind can't be opened.

**Why this design.** Revoking access is immediate and complete: delete one row. Deleting the account deletes every copy of the key, so the data left in storage becomes unreadable without anyone having to find every copy of the data. This is often called crypto-shredding.

**Where it's weak.**

- Whatever an assistant already received stays with that assistant and its provider.
- Old backups still hold the old locked copies until they expire. Someone with both an old backup and a token that was valid when it was taken could open it, so backups need a short, fixed lifetime.
- Revoking the service's tokens at each source account is a separate step. The service revokes them where the source supports token revocation (RFC 7009). Where it doesn't, the token stays valid at the source until it expires there.

## 6. Lifecycle of each credential

For each credential: where it is born, where it is kept, how it moves, how it is used, how it rotates and how it is retired.

### Account key

- **Born:** on the companion app's first run, from the OS random number generator. 256 random bits.
- **Kept:** in the OS keystore on the person's computer, which is the source of truth. On the server, only as locked copies.
- **Moves:** never in the clear. Only as locked copies, or sealed to a new device's one-time public key during approval.
- **Used:** on the server, in memory, for one request. It derives the content and tag keys, and opens the X25519 private key and the source account tokens.
- **Rotates:** not specified yet (section 11). Rotating means re-encrypting the mirror, or adding a layer of data keys under the account key.
- **Retired:** at account deletion. Losing every holder also makes the mirror unreadable.

### Locked copy and unlock secret

- **Born:** when a holder is admitted: on first run, when a connect code is redeemed, at the token exchange after consent, when a personal access token is minted, and when a new device is approved.
- **Kept:** the copy in the database. The secret only inside the holder's token.
- **Moves:** the secret travels with every request, inside the token, over TLS.
- **Used:** HKDF-SHA256 turns the secret into a key-encryption key, which unwraps the copy for that request.
- **Rotates:** with the token. A refresh re-wraps the copy under a new secret.
- **Retired:** deleting the copy ends that holder's access at once.

### Account keypair

- **Born:** with the account key, on the companion app.
- **Kept:** the public half in the database, in the clear. The private half wrapped under the account key.
- **Moves:** the public half goes to every part of the service that seals arrivals.
- **Used:** to seal arrivals from email, chat apps and source events. The private half opens them inside the next holder's call.
- **Rotates:** with the account key. Sealed arrivals must be opened before the old private key is dropped.
- **Retired:** at account deletion.

### Support key and support copy

- **Born:** the support key once, inside the KMS, by the operator. A support copy each time the person turns on Debug access.
- **Kept:** the private half never leaves the HSM. The support copy sits in the database with its end time.
- **Moves:** nothing leaves the KMS. The server sends the support copy in and gets the account key back for one request.
- **Used:** by support staff with a specific access role and two-step sign-in. Every decrypt is written to the KMS's audit log, and the person's list is built from that log.
- **Rotates:** through KMS key versions. A support copy is re-wrapped to the newest version on its next use.
- **Retired:** the copy at its end time, or when the person turns Debug access off.

### Device token

- **Born:** at sign-in on the companion app. The server makes the lookup part, and the app makes the unlock secret.
- **Kept:** in the OS keystore, hardware-backed where available. The server keeps the hash of the lookup part.
- **Moves:** in the HTTPS Authorization header (RFC 6750), to the service only.
- **Used:** to find the device's copy and open it.
- **Rotates:** not on a schedule in this draft. A device can re-wrap its copy under a new secret on any call, so periodic rotation is cheap to add.
- **Retired:** at sign-out, at removal in settings, or at account deletion.

### Session cookie and connect code

- **Born:** the connect code when the companion app asks for one. The session at redeem time, with its own secret and copy.
- **Kept:** the code only in the URL fragment, for seconds. The session in an HttpOnly, Secure, SameSite cookie, and never in browser storage that page scripts can read. The server keeps hashes.
- **Moves:** the cookie, to the service only. Requests that change state must come from a trusted origin.
- **Used:** as a holder, with the rights of the device that opened it.
- **Rotates:** opening a new dashboard session from the same device replaces that device's previous session.
- **Retired:** the session at sign-out in the dashboard, when the device that opened it is revoked, at a maximum age, or at account deletion. The code when it is redeemed, after 60 seconds, or by the cleanup sweep.

### Access token, refresh token and authorization code

- **Born:** the authorization code at consent. The access and refresh tokens at the token exchange, together with the assistant's secret and copy.
- **Kept:** by the assistant's client. The server keeps hashes.
- **Moves:** the access token as a bearer header on MCP calls only. The refresh token to the token endpoint only.
- **Used:** the access token opens the assistant's copy for one MCP call, within its scopes.
- **Rotates:** each refresh spends the refresh token, re-wraps the copy under a new secret, and returns a new pair.
- **Retired:** the access token at expiry. Both when the person disconnects the assistant, at account deletion, or when a spent refresh token is presented again.

### Personal access token

- **Born:** minted from settings, inside a dashboard session that holds the key. The person names it and picks its scopes and expiry. The server makes its secret and its own locked copy, shows the token once, and does not keep it.
- **Kept:** wherever the person keeps it. The server keeps the hash.
- **Moves:** as a bearer header on REST or MCP calls.
- **Used:** like an assistant's access token, limited to its scopes.
- **Rotates:** by minting a new one and deleting the old one.
- **Retired:** at its expiry, or when the person deletes it in settings, which deletes one row.

### Source account tokens

- **Born:** when the person connects a source account through that source's own OAuth flow, inside a call that holds the key.
- **Kept:** in the database, wrapped under the account key.
- **Moves:** unwrapped in memory to call the source, inside a holder's call only.
- **Used:** to pull new data from the source.
- **Rotates:** as the source requires.
- **Retired:** when the person disconnects the source, or at account deletion. The service also revokes the token at the source, where the source supports it (RFC 7009).

## 7. Platform independence

The server never knows what kind of computer a holder runs on. Everything it stores and checks uses published standards, so a companion app on any operating system that produces the same bytes is one more holder with its own locked copy. The server, the database and the assistant path stay as they are.

| Piece | The same on every platform | Written per platform |
|---|---|---|
| Account key | 256 random bits, AES-256-GCM for content | The random source: the OS random number generator |
| Locked copy | HKDF-SHA256 and AES key wrap (RFC 5649) | Nothing |
| Sealed arrivals | X25519 and HPKE (RFC 9180) | Nothing |
| Search and identity tags | HMAC-SHA256 under keys derived from the account key | Nothing |
| Tokens | Bearer tokens over HTTPS | Nothing |
| Where the key and token are kept | Nothing | The OS keystore, ideally a hardware-backed keystore: a trusted platform module (TPM) or a secure enclave |

Only two things are written per platform: the keystore and the random source.

**A caveat.** Some desktop keystores can be read by any process running in the user's session. On those platforms the companion app must seal the key with hardware, such as a TPM, or with a passphrase, to give the same protection.

For this to hold in practice, the design also needs a written wire format with test vectors, and ideally one shared core library (section 11).

## 8. Performance

Decryption is not where the time goes. The key is opened once per request, in memory, with no network call. Only the rows in the answer are decrypted. Search uses the same kind of inverted index a plaintext trigram search would use, built over keyed tags instead of plaintext fragments.

| Step | Work | Estimated cost | Compared with an unencrypted mirror |
|---|---|---|---|
| Find the holder | One indexed lookup by token hash | Under 1 ms | The same lookup any token check makes |
| Unlock the key | HKDF plus one key unwrap, in process | Microseconds | New, and negligible |
| Search | Inverted-index lookup on keyed trigram tags | Milliseconds | The same kind of index as a plaintext trigram search |
| Decrypt the answer | AES-256-GCM, hardware-accelerated | About 1 µs per KB | New, and negligible for 50 rows |
| Recheck | Run the real query on the candidates | About 1 ms | A plaintext trigram index rechecks its candidates too |

These are estimates, not measurements. They should be measured on a synthetic account of about a million messages before anyone relies on them. Two costs are not in the table: building tags for each new message when it is written, and the size of the tag index, which grows with the number of distinct fragments.

## 9. Verification levels

Encryption on its own still asks people to trust the operator. To make the claims checkable from outside, three things have to be provable: the code that handles keys is public, each release is a build anyone can reproduce, and the running server can prove which build it is. Each level adds to the one before.

![Public source is built reproducibly. Each release digest is signed and recorded in a public transparency log, and deployed to a hardware-attested confidential VM. An independent reviewer reads the source, anyone can rebuild and compare digests with the log, and the companion app verifies the attestation.](./architecture-10.png "How someone outside the service can check it")

### Level 1: review

- **The operator does:** publishes the key-handling code and this design, commissions an independent cryptography review, and publishes the report.
- **Outsiders can check:** that the design and the code are sound.
- **It doesn't prove:** that the server runs that code.

### Level 2: transparency

- **The operator does:** builds each release reproducibly, with SLSA provenance (a signed record of how the build was made), signs each release digest and records it in a public transparency log, an append-only log that anyone can audit, and has a public status endpoint report the digest that is running. A verify page in the companion app lists every holder and every support use, taken from the KMS's audit log.
- **Outsiders can check:** that each release is a logged build, and who can open the account key.
- **It doesn't prove:** that the running process is that build.

### Level 3: attestation

- **The operator does:** runs the server in a hardware-attested confidential VM: a virtual machine whose memory the processor encrypts, and which can prove to others which software it booted. Locked copies are wrapped a second time with a server key that the KMS releases only to a VM that attests to a logged digest. The companion app checks the attestation before it sends its token, so it never unlocks its copy on an unattested server. AI assistants cannot check attestation themselves, so they rely on the second wrap.
- **Outsiders can check:** that the server is that build and cannot be logged into, by the operator included. A stolen token is useless on any other build.
- **It costs:** moving the server from a machine operators can log in to, into a sealed one. That is a project of its own.

## 10. Limits

What this design does not promise.

- **During a request.** While answering a holder, the server holds the account key and plaintext in memory. Until level 3, a malicious change to the service's own code could capture them.
- **The AI assistant's own copy.** An assistant and its provider see what the assistant asks for and keep it under their own terms. Disconnecting the assistant stops new reads; it cannot recall old ones.
- **The people on the other side of a conversation.** Every message has at least two ends. The people a person writes to keep their own copies, in their own accounts, and this design does nothing for those. Their messages also sit in this person's mirror under this person's key, without their say.
- **Structure stays visible.** Timestamps, sizes, counts, and which rows share a keyed fragment are visible to the server. Tags are per account, so they cannot be matched across accounts.
- **The moment of arrival.** Data that arrives while no holder is calling is in the clear on the server for the moment before it is sealed.
- **Source account tokens.** The design holds only if the tokens for source accounts are wrapped under the account key. Otherwise the service could read the sources directly, and encrypting the mirror would protect little.
- **A compromised holder.** Malware on the person's computer, or a leaked token, has whatever access that holder has, until it is removed.
- **Loss.** Losing every holder makes the mirror unreadable. There is no recovery key, by design.
- **Debug access.** While it is on, support staff with the right role can read the mirror.
- **Adopting it later.** A service that adopts this design for existing accounts still has backups holding plaintext until those backups expire.

## 11. Open questions we want input on

1. **Account-key rotation.** When and how should the account key be replaced? One option re-encrypts everything under a new key. Another keeps the account key as a key-encryption key over a series of data keys, so rotation re-wraps data keys only. What should trigger it: a suspected leak, a removed device, or a schedule?
2. **Adding a second device.** This draft uses the lost-device approval (5.7) for every new device. Is approval from the dashboard enough, or should an existing device approve directly, for example by scanning a code? What should a person with only one device do to avoid losing everything with it?
3. **A written wire format with test vectors.** Versioned envelopes for the locked copy, for content values and their associated data, for sealed arrivals, and for tag derivation, including the HKDF labels, the cut to 64 bits and how text is normalized before tagging. Every implementation would have to pass the same test vectors.
4. **The default length of Debug access.** Hours or days, and renewable or not? One suggestion is 72 hours, renewable from the same setting.
5. **Background features.** How should features that read new data, such as sorting, filing and alerts, work when new data stays sealed until a holder calls? Options include running them inside the next call, running them on the companion app, letting the person opt in to a time-limited server copy for background work, or accepting the delay.
6. **Keyed trigram tags.** Do they leak too much structure? Counting how often each tag appears within one account can hint at common fragments. Options include fewer bits per tag, padding, separate keys per field, or a different searchable-encryption scheme.
7. **A shared core crypto library.** Should there be one library, written once and built for every platform, so that every companion app and the server produce the same bytes? Or independent implementations, each checked against the test vectors?

## 12. Related work

We looked for open standards that say how an AI assistant's access to a person's data should be tied to keys held per holder. No finalized open standard for per-holder key custody for AI access was found as of November 2026. The nearest work is below. Each link was checked on 11 November 2026.

- **IETF Internet-Draft "Ciphertext-Based AI Inference Tool Design for the Model Context Protocol (MCP)"**, draft-li-pearg-ciphertext-inference-tool-mcp-00, published 29 June 2026. It proposes an MCP extension that uses homomorphic encryption, so that a tool computes on encrypted inputs and returns a result only the client can decrypt. It is an individual draft with no formal standing in the IETF, and no working group or research group has adopted it. It keeps data encrypted while the tool computes. This design instead decrypts in server memory for one request (section 10). <https://datatracker.ietf.org/doc/html/draft-li-pearg-ciphertext-inference-tool-mcp-00>
- **OpenID Foundation, Artificial Intelligence Identity Management Community Group.** It assesses use cases, terminology and gaps in identity standards for AI agents, such as how an agent asserts its identity to the servers it calls. Its charter leaves protocol development to working groups. <https://openid.net/cg/artificial-intelligence-identity-management-community-group/>
- **OpenID Foundation, AuthZEN Working Group.** On 15 June 2026 it approved two working group drafts that build on the AuthZEN Authorization API: the Access Request and Approval Profile, for decisions that need a prerequisite such as approval or consent before they can be made, and a profile for authorizing MCP tool calls. <https://openid.net/openid-foundation-advances-authorization-for-the-agent-era-with-new-authzen-working-group-drafts/>
- **W3C Agent Identity Registry Protocol Community Group.** It develops open specifications for verifiable AI agent identity: a DID method, an agent credential format based on W3C Verifiable Credentials, a trust negotiation protocol, and integration profiles for MCP and OAuth. Community group reports are not W3C standards. <https://www.w3.org/groups/cg/agent-identity/>
- **The MCP authorization specification**, revision 2026-07-28. It makes an MCP server an OAuth 2.1 resource server and asks for protected resource metadata (RFC 9728), authorization server metadata (RFC 8414), resource indicators (RFC 8707) and client ID metadata documents. It keeps dynamic client registration (RFC 7591) only for backward compatibility. Section 5.3 follows it. <https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization>

These address who an agent is and what it may do. This design addresses a different layer: which keys open a person's data, who holds each one, and how each is revoked.

### Standards this design uses

| Building block | Standard |
|---|---|
| AES-256-GCM | NIST SP 800-38D, and RFC 5116 for its use as an AEAD |
| AES key wrap with padding | RFC 5649 |
| HKDF-SHA256 | RFC 5869 |
| HMAC-SHA256 | RFC 2104, with SHA-256 from FIPS 180-4 |
| X25519 | RFC 7748 |
| HPKE | RFC 9180 |
| RSA-OAEP | RFC 8017 |
| OAuth 2.1 | draft-ietf-oauth-v2-1, still an Internet-Draft as of November 2026 |
| PKCE | RFC 7636 |
| Bearer tokens | RFC 6750 |
| Dynamic client registration | RFC 7591 |
| Client ID metadata documents | draft-ietf-oauth-client-id-metadata-document |
| Authorization server metadata | RFC 8414 |
| Protected resource metadata | RFC 9728 |
| Resource indicators | RFC 8707 |
| OAuth security best current practice | RFC 9700 |
| Token revocation | RFC 7009 |
| Cookies, with HttpOnly, Secure and SameSite | RFC 6265 |
| Build provenance | SLSA |
| Hardware key storage | TPM 2.0 |
| AI assistant protocol | MCP |
