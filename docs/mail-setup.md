# Mailing each session's CSVs — one-off setup

At the end of every participant session, `utils.mailSession` zips that
participant's CSVs and emails them to `cfg.mail.to`. Gaze buffers and `.mat`
files are never attached, so the zip is kilobytes.

This needs one credential to exist. Creating it takes about five minutes, once.
After that there is **nothing to set up per user and nothing to set up per
machine** — which is the whole point of how it is stored.

## Why the credential lives on the share

The rig is run by whoever is logged in: Murray some days, a PhD student or an RA
on others. A password in an environment variable or in MATLAB's preferences
belongs to **one Windows account** and silently does nothing for everyone else —
the failure mode being sessions that quietly stop mailing when someone else runs
them.

So it lives beside the data instead:

```
\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages\.mail\credentials.json
```

Everyone who runs the battery already has read access to that share — they must,
because that is where the participant data is written. Anyone who can read this
file can already read every participant CSV, so it grants nothing new. And it
keeps working on a reimaged machine, under a new RA's login, with no setup.

The app password is never written into any user's `matlabprefs.mat`:
`utils.mailFile` sets the SMTP preferences, sends, and restores the previous
preference state in an `onCleanup`, including removing preferences that did not
exist beforehand.

## Setup

**1. Use a dedicated Gmail account, not your main one.**

The credential is readable by everyone with share access. That is fine for a
send-only account created for this purpose; it is not fine for an account that
holds your actual email. Make a new one — the delivery address stays
`murray.bennett92@gmail.com`, only the *sending* account is new.

**2. Turn on 2-Step Verification** on that account. Google will not offer app
passwords without it.

**3. Create an app password.** Google Account → Security → 2-Step Verification →
App passwords. Google shows a 16-character string. That is what goes in the file
— *not* the account password. Gmail has refused plain account passwords over
SMTP since 2022, and the resulting error does not say so clearly.

**4. Create the credential file** at the path above:

```json
{
  "from": "housing.decisions.rig@gmail.com",
  "password": "abcdefghijklmnop"
}
```

`server` (`smtp.gmail.com`) and `port` (`465`) are optional overrides.

**5. Prove it works, at the rig:**

```matlab
cd <repo>\scripts
test_mail
```

This sends a two-line CSV through the same code path a real session uses. Run it
on **each machine** that will run sessions — see the next section for why.

## The one thing that cannot be checked from a laptop

Institutional networks frequently block outbound SMTP on ports 465 and 587. The
OSU wired network may or may not; that is invisible from anywhere except the rig
itself, and no amount of reading the code will settle it.

`test_mail` answers it in thirty seconds. If it fails on the network rather than
the credential, **no data is at risk** and no session behaviour changes — see
below.

## When sending fails, nothing is lost

Delivery is eventually consistent by design:

1. `utils.mailSession` writes the zip into `Data\outbox\` **before** touching
   the network.
2. It tries to send.
3. Only on success does the zip move to `Data\outbox\sent\`.

So whatever remains in `outbox\` is exactly what never went out. The RA sees a
few lines saying it is queued and that there is nothing for them to do, and the
session continues normally. Later, from any machine that can reach the share:

```matlab
cd <repo>\scripts
flush_outbox              % or flush_outbox('dryRun', true) to just look
```

If the lab network turns out to block SMTP permanently, this is also the fallback
posture: let sessions queue, and flush from a machine that can send. The rig
needs no network access to mail for the data to arrive.

## What is and is not mailed

- **Mailed:** the session timing CSV and every task run CSV for that
  participant/session, matched on the `sub-%05d_ses-%02d_` prefix. The fallback
  data tree is scanned too — if the share went unreachable mid-session, those
  runs exist only on the rig's local disk, and they are the ones most worth
  getting off it.
- **Not mailed:** gaze data, `.mat` files, crash dumps, anything from a
  `TESTING` run (participant 9999), anything from a `practice` run.

`utils.mailSession` never throws. By the time it runs the session is over and
the data is already saved; a mail problem must not look to an RA like lost data.

## Turning it off

`cfg.mail.enabled = false` in `experiment/+utils/config.m`. The share plus
`scripts/pull_data_from_share.ps1` remains the system of record either way —
this feature is immediacy and a second copy, not the data path.

## Note on where the data goes

The CSVs are keyed by participant number and carry no names, so what leaves OSU
systems is pseudonymous rather than identifiable. It is still study data going to
a personal Gmail account, which was raised and is a deliberate choice. If the
protocol ever needs it kept inside the institution, change `cfg.mail.to` to an
OSU address; nothing else needs to change.
