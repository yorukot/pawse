# Security Policy

## Supported Versions

Security fixes are applied to the latest public release and the current `main` branch. Older builds may not receive fixes.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately to `hi@yorukot.me` with the subject `Breather security report`.

Include, when possible:

- The affected version or commit
- The macOS version and hardware architecture
- A clear description of the impact
- Minimal reproduction steps or a proof of concept
- Any suggested mitigation

Do not open a public issue for an undisclosed vulnerability and do not include personal data, real session history, or sensitive screenshots in a report.

You should receive an acknowledgment within seven days. After validation, the maintainer will coordinate a fix and responsible disclosure. Please allow reasonable time for a patch before publishing technical details.

## Security Scope

Breather is a self-discipline utility, not a security boundary. A user can intentionally terminate it through macOS system tools. Reports about bypassing a break by force-quitting the app are therefore out of scope.

Privacy regressions, unsafe presentation-option cleanup, unintended file access, and ways the app could leave overlays or system UI in a broken state are in scope.
