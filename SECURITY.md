# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Studio, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email **admin@diskrot.com** with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will acknowledge receipt within 48 hours and aim to provide a fix or mitigation plan within 7 days for critical issues.

## Scope

This policy applies to the Studio repository and its official Docker images. For vulnerabilities in vendored dependencies (ACE-Step, Bark, llama.cpp), please also report upstream.

## Security Considerations

Studio is designed to run locally. By default, all services bind to `127.0.0.1` except the frontend and backend which are intended to be accessed by the user's browser. Do not expose Studio services to the public internet without additional security measures.
