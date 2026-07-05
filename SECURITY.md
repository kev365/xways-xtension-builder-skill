# Security Policy

This repository ships a Claude Code skill, X-Tension starter templates, and
documentation. The templates produce X-Tensions that run **inside** X-Ways
Forensics (with the same privileges as X-Ways) and may wrap external
command-line tools and parse untrusted evidence data.

## Reporting a vulnerability

Please **do not** open a public issue for a security problem. Use GitHub's
private vulnerability reporting:

1. Repository **Security** tab → **Report a vulnerability**.
2. Describe the issue, the affected file/template, and steps to reproduce.

This is a volunteer community project — please allow reasonable time before any
public disclosure.

## In scope

- Memory-safety / parsing bugs in the starter templates' convention code
  (helper-exe verification, subprocess launch, output handling).
- Command-injection or unsafe handling patterns in the `wrapper` template or the
  convention guidance.
- Unsafe patterns in the PowerShell scripts (`scripts/*.ps1`).

## Out of scope

- Vulnerabilities in X-Ways Forensics itself — report to
  [X-Ways AG](https://www.x-ways.net/).
- Vulnerabilities in upstream tools an X-Tension wraps — report to those
  projects.

## Good practice for users

- Build from source or download helper binaries only from official tool releases.
- Never commit live `.cfg` sidecars — they may hold DPAPI-encrypted credentials.
  See [docs/conventions/repo-hygiene.md](docs/conventions/repo-hygiene.md).
