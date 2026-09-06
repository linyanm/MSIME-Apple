# Privacy

Metasequoia IME for macOS processes keystrokes, pre-edit text, and candidates locally on the user's Mac. The keyboard engine does not send typed text, candidates, learned words, preferences, diagnostics, analytics, or crash reports over the network. It does not include cloud synchronization.

Updates use [Sparkle](https://sparkle-project.org), not the GitHub API. The app fetches a signed appcast from `https://github.com/metasequoiaime/MSIME-Apple/releases/latest/download/appcast.xml` on Sparkle's default schedule (about once a day) and when the user asks for a check. The request carries no typed text, preferences or dictionary data; GitHub may see the IP address and standard request metadata. System profiling, which Sparkle can attach to update checks, is off -- `SUEnableSystemProfiling` is not set, so no hardware or OS inventory is sent.

Two Sparkle settings in `Info.plist` are worth stating because they are what make the update path trustworthy rather than merely encrypted: `SURequireSignedFeed` and `SUVerifyUpdateBeforeExtraction` are both true, so an update is checked against the project's Ed25519 public key (`SUPublicEDKey`) before it is unpacked. A tampered appcast or archive is rejected even though the macOS build itself is not yet Developer ID signed.

The input method stores its settings in the current user's macOS preferences. When candidate learning is enabled, learned word-frequency changes are stored locally under `~/Library/Application Support/metasequoiaime/`. The bundled dictionary is copied to the same directory so it can be upgraded safely. These files are available only through the permissions of the local macOS account; users should protect that account and its backups as they would other personal data.

The settings panel can disable candidate learning and can erase learned input data. If learning is disabled while a composition is active, that composition keeps the setting it started with; after it is committed or cancelled, newly started compositions do not update word frequencies. Erasing learned data removes the local learning databases and restores the bundled dictionary without deleting unrelated preferences.

Voice input starts only when the user chooses the menu action or presses Control+Option+V, after macOS microphone permission is granted. In cloud mode, the current recording is sent to the HTTPS endpoint configured by the user. In local Whisper mode, audio is processed on this Mac using the selected model. If optional text cleanup is enabled, the transcription is sent to the separately configured cleanup endpoint, including when recognition itself is local. Provider processing and retention follow that provider's policies.

Audio is held in memory for the request (up to 60 seconds) and is not written to recording files. Cancelling, typing, moving focus or changing the insertion point prevents a late result from being inserted. Cancelling a request cannot recall data already received by a configured service. API tokens are stored in the system Keychain, scoped to service origins; ordinary voice preferences contain no tokens. Local models are files selected by the user, not downloaded automatically.

Metasequoia IME does not sell personal data. Installing or using the software does not create a Metasequoia account. Network-backed features and any future changes to their data flows are described here before shipping.

Security or privacy concerns should be reported privately as described in [SECURITY.md](SECURITY.md).
