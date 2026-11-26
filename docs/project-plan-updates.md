# eBarangay Mo: Project Plan Corrections

Apply these to the Project Plan so it matches the app as of 2026-11-24.
Each item gives the section to change and the text to use.

## Section 1: Proposal and Scope

**Opening paragraph.** Replace "That residents repeat trips" with:

> This saves residents repeat trips

**User Roles, Admin.** Add:

> Once a concern is Resolved or Rejected, it is final. Admins can still read it,
> but no one can change its status or dates or add a reply.

**User Roles.** Replace the Resident/Guest item with two items:

> **Resident:** Submits concerns, uploads IDs and evidence, chooses a preferred
> claiming date for document requests, sees only their own concerns and files,
> and edits their own profile.
>
> **Guest:** Anyone not logged in. Can only register and log in.

**In Scope.** Replace the first bullet with:

> Residents register with email and password, confirmed by a 6-digit email code,
> or continue with Google. Sessions use short-lived access tokens with a rotating
> refresh cookie.

**In Scope.** Add to the document request bullet:

> Residents choose a preferred weekday claiming date within 90 days. An admin
> approves it or sets another date.

**In Scope.** Replace the status bullet with:

> Residents can see whether each submission is Pending, Ready for Pickup
> (document requests only), Resolved, or Rejected.

**In Scope.** Replace the admin bullet with:

> Admins review concerns and attachments, set dates, sort records by newest or
> oldest, filter by type and status, and receive in-app notifications for new
> requests, reports, and complaint replies.

**Out of Scope.** Replace "PVI-DSS" with "PCI-DSS". Replace the email bullet with:

> SMS notifications and email-based password reset. Email is used only to send
> sign-up verification codes. Reset links are a common route for account takeover.

## Section 2: Data Privacy

**First paragraph.** Replace "and the Railway, which hosts the system, acts as a
personal information processor" with:

> and Railway, which hosts the system, and Resend, which delivers verification
> emails, act as personal information processors

**Cross-border transfer.** Add:

> Resend may process a resident's email address and verification code abroad.
> The privacy notice says so.

**Closing line.** Replace "Two items are still open..." with:

> Both earlier open items are complete. The sign-up page has a privacy notice with
> a required consent checkbox, and a daily scheduled job deletes attachments one
> year after a concern is closed.

## Section 3: Database Design

Replace "six InnoDB tables" with "seven InnoDB tables".

Update the ERD:

- Rename the **bottom-left box** from `audit_logs` to `refresh_tokens`. It is
  mislabeled because it shows `token_hash`, `family`, and `replaced_by`.
- Add **concern_messages**: `id`, `concern_id` (FK to concerns), `user_id` (FK to
  users), `sender_role`, `body` (encrypted), `created_at`.
- Add to **users**: `email_verified_at`, `verification_code_hash`,
  `verification_expires_at`, `verification_sent_at`, `verification_attempts`,
  `privacy_consented_at`.
- Add to **concerns**: `resident_read_message_id`, `admin_read_message_id`.

In the closing paragraph, replace "field concerns" with "filed concerns" and
"`request_date`" with "`requested_date`". Add:

> Document requests also use `requested_date` for the resident's preferred
> claiming date. The official date stays in `claim_date`, which only an admin can set.

## Section 5: Hosting and Infrastructure

Add after "Security posture":

> **Email delivery.** Railway disables outbound SMTP below the Pro plan, so
> production sends verification codes through Resend's HTTPS API. Local development
> can use Gmail SMTP. The Resend API key is stored as a Railway service variable,
> and the sender address uses a domain verified with Resend.

Add `RESEND_API_KEY` to the list of secrets.

## Section 6: Tech Stack and Vulnerability

- Rename the heading from "Teach Stack" to "Tech Stack".
- Rename the table column from "Mitagation" to "Mitigation".
- Replace "Laravel 12.69.2" with "Laravel 12.73.0" in both places.
- Replace "MySQL 8 with InnoDB (8.0.45 locally, Railway MySQL in production)" with:

> MySQL 8 with InnoDB on Railway in production; MariaDB 10.4.32 through XAMPP locally

## Section 7: Security Implementation

Replace the opening test sentence with:

> All controls required by section 3 of the brief are built, and 58 automated tests
> check them (`cd server && php artisan test`: 58 passed, 486 assertions, on
> 2026-11-24).

Add to **Middleware & API**:

| Control | How it is built | Evidence |
| --- | --- | --- |
| Email verification | 6-digit code stored only as an HMAC, valid for 10 minutes and 5 wrong tries. Each inbox gets at most 1 code a minute and 5 an hour. | `EmailVerificationTest` |
| Closed records | Resolved and Rejected concerns are locked on the server, using a database row lock. | `test_resolved_concern_cannot_be_changed_or_replied_to`, `test_rejected_concern_cannot_be_changed_or_replied_to` |

## Section 8: Dependency Scans

`composer audit` was clean again on 2026-11-24. Re-run the Dart and Flutter
OSV check before changing that package's scan date.
