# Example Spec: User Authentication

This is an example spec file. Delete it and create your own specs in this directory.

## Overview

Implement user authentication with email/password login.

## Requirements

- Users can register with email and password
- Passwords must be at least 8 characters
- Users can log in with valid credentials
- Failed login attempts return generic error (no user enumeration)
- Authenticated routes require valid session/token

## Acceptance Criteria

- [ ] Registration endpoint creates new user
- [ ] Login endpoint returns session token
- [ ] Protected routes reject unauthenticated requests
- [ ] All tests pass

## Notes

- Use bcrypt for password hashing
- Session tokens expire after 24 hours

---

## Spec Writing Tips

**One topic per file**: Split `auth.md`, `api.md`, `database.md` into separate specs.

**Be specific**: "Password must be 8+ characters" not "secure passwords".

**Include acceptance criteria**: Checkboxes the agent can verify.

**Avoid implementation details**: Say what, not how. Let the agent choose libraries and patterns.

**Keep it brief**: The agent reads all specs every iteration. Concise specs reduce token usage.
