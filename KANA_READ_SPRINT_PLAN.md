KANA READING PRACTICE — SPRINT PLAN


Program Context \& Goal

This project is a Godot desktop Japanese learning application whose purpose is to train direct sound-to-symbol association for Japanese kana using spoken input only (no romaji, no typing). The user is shown kana on screen, speaks the sound aloud, and the system uses an offline Vosk speech-recognition backend (running as a local companion service) to transcribe and grade the response in real time. The goal is to build a minimal, low-latency, privacy-preserving practice loop that reinforces accurate phonology, mora timing, and recall through immediate feedback, and that can later be extended to words, phrases, and pronunciation analysis. The Codex agent’s role is to implement this system exactly as specified in the tasks, respecting the locked architecture (Godot frontend + local Vosk backend) and maintaining clean separation between UI, lesson logic, speech recognition, and grading.


Sprint length assumption: ~1 week per sprint

Total sprints: 6

Order is strict.



SPRINT 1 — Foundations \& Speech Backend

Goal: Vosk runs locally and can transcribe audio.

Tasks



S1.T1 — Repo \& structure

* Create folders: /speech/, /ui/, /lessons/, /services/
* Create empty KanaReadingPractice scene



S1.T2 — Download Vosk model

* Acquire vosk-model-small-ja-0.22
* Place in /models/



S1.T3 — Build Vosk service

* Implement WebSocket server
* Load model
* Accept PCM frames
* Emit partial + final JSON



S1.T4 — Package Vosk service

* Build standalone executable
* Verify runs without Python installed



S1.T5 — Verify transcription

* Test mic input → Japanese text output



SPRINT 2 — Godot Speech Integration

Goal: Godot launches Vosk and receives text.



Tasks

S2.T1 — VoskServiceManager autoload

* Detect running service
* Start service if missing
* Retry connection logic



S2.T2 — WebSocket client

* Connect to localhost
* Send audio frames
* Receive JSON



S2.T3 — Microphone capture

* Capture mic audio
* Convert to 16kHz mono PCM
* Silence detection



S2.T4 — End-to-end test

* Speak Japanese
* See transcript in Godot debug log



SPRINT 3 — Lesson Data \& State Machine

Goal: Core flow exists without UI polish.



Tasks

S3.T1 — Lesson schema

* Define kana assignment JSON



S3.T2 — Populate kana\_basic.json



S3.T3 — FSM implementation

* Define states
* Implement transitions



S3.T4 — Hook transcription into FSM

* LISTENING → PROCESSING → FEEDBACK



SPRINT 4 — UI \& Feedback

Goal: Usable player-facing experience.

Tasks



S4.T1 — Kana display

* Centered large kana
* Animated glow



S4.T2 — Status text

* “Speak now”
* “Correct”
* “Try again”



S4.T3 — Feedback animations

* Green glow
* Red pulse



S4.T4 — Timing polish

* Prompt delay
* Feedback duration



SPRINT 5 — Grading \& Error Handling

Goal: Robust correctness and failure handling.



Tasks

S5.T1 — Normalization

* Unicode normalize
* Katakana → hiragana
* Trim punctuation



S5.T2 — Levenshtein scoring



S5.T3 — Retry logic



S5.T4 — Error states

* No mic
* Vosk unavailable
* Timeout



SPRINT 6 — Packaging, QA, and Stabilization

Goal: Shippable build.



Tasks

S6.T1 — Bundle Vosk with export



S6.T2 — Verify relative paths



S6.T3 — Performance testing



S6.T4 — Noise robustness testing



S6.T5 — Final bugfix pass

