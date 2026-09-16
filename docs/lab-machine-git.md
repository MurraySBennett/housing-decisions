# Putting the lab machine on git

Retires `scripts/deploy_to_share.ps1`. Written 2026-09-16, after the staff
pilot, because a one-way manual copy is what let the two copies diverge
before (`docs/shared-drive-parity-2026-09-10.md`).

**Do this at the rig.** Steps 1–4 need a keyboard on the lab machine.

**Step 3 blocks the rest** — participant data currently sits inside the
tree that is about to become a git checkout.

## First, what git can and cannot replace

The share holds four different kinds of thing and git is the right tool for
exactly one of them:

| on the share | size | git? |
|---|---|---|
| Code — `Experiment/*.m`, `+utils/`, stimulus CSVs, `analysis/R/` | ~2 MB | **yes**, this is the repo |
| `Experiment/stimuli/house_images/` | 605 MB | no — gitignored, share only |
| `Experiment/Data/` — participant data | grows | **never.** Human-subjects data does not go in a git history, and a history is not deletable in the way a directory is |
| `PSY-kvam.4/TobiiPro.SDK.Matlab_1.9.0.59/` | vendor SDK | no — lives *above* `housing_wages/`, outside the project entirely |

So git does not make the share redundant. It replaces the copy step, and
turns `git status` on the lab machine into the parity check that nothing
currently provides.

## The layout, and why `housing_wages/` is the working tree

`utils.config` defaults `projRoot` to
`\\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4`, and everything hangs
off it — `cfg.paths.experiment` is `<projRoot>\housing_wages\Experiment`.

The repo's `experiment/` and the share's `Experiment/` differ only in case,
and Windows does not distinguish them. So cloning the repo *as*
`housing_wages/` lines the two up with no path changes, no config edits,
and no second root:

```
PSY-kvam.4\
  TobiiPro.SDK.Matlab_1.9.0.59\     <- outside the repo, leave alone
  housing_wages\                    <- the working tree
    experiment\   (= Experiment\)   <- tracked
      stimuli\house_images\         <- gitignored, stays put
      Data\                         <- gitignored, stays put
    analysis\                       <- tracked
    docs\  scripts\  WORK.md        <- tracked, new to the share
    Archive\  screen_recordings\    <- gitignored, stays put
```

The alternative — clone to the lab machine's `C:` and point `projRoot`
there — is faster (git over SMB is slow) but needs the code root and the
data/image root to become two different settings, which they currently are
not. Not worth it for one machine.

## 1. Install git

[git-scm.com/download/win](https://git-scm.com/download/win). Defaults are
fine; the one setting that matters is line endings, and
[`.gitattributes`](../.gitattributes) already pins the policy (`* text=auto`,
LF in the repo, CRLF in the Windows working tree), so whatever the installer
chooses is overridden by the repo.

```powershell
git --version
git config --global user.name  "..."
git config --global user.email "..."
```

## 2. Give the machine read-only access

The repo is **private**. A shared lab machine should not hold credentials
that can push, and should not be signed in as a person.

Use a **deploy key** — an SSH key tied to this one repository, read-only:

```powershell
ssh-keygen -t ed25519 -C "kvam-lab-rig" -f $env:USERPROFILE\.ssh\housing_deploy
type $env:USERPROFILE\.ssh\housing_deploy.pub
```

Paste the public key at
`github.com/MurraySBennett/housing-decisions/settings/keys/new`, title it
`kvam lab rig`, and **leave "Allow write access" unchecked**. Then point ssh
at it:

```powershell
Add-Content $env:USERPROFILE\.ssh\config @"
Host github-housing
  HostName github.com
  User git
  IdentityFile ~/.ssh/housing_deploy
"@
```

The lab machine now pulls and never pushes. Edits happen on the dev machine
and arrive by `git pull`. If you ever *do* need to commit from the rig,
commit locally and pull it the other way rather than giving the rig a
writable key.

## 3. Data and images out of the tree — DONE 2026-09-16

Both were gitignored and *inside* what is about to become the working tree.
That combination is the dangerous one: `git clean -fdx` removes ignored
files — the whole point of `-x` — and it is the command anyone reaches for
to reset a checkout. On that tree it deletes every participant, and git
raises no objection, because they were ignored by design. The deploy
script's `Archive\` backups exclude both, so there is no second copy.

`scripts/move_out_of_tree.ps1` moved them and verified file counts and
bytes on both sides:

```
housing_wages\Experiment\Data                  ->  housing_wages_local\Data
   41 files, 2,796.3 MB
housing_wages\Experiment\stimuli\house_images  ->  housing_wages_local\house_images
  485 files, 605.3 MB
```

`cfg.paths.local` in `+utils/config.m` points at the new root, and
`utils.verifyPaths` now lists it under MUST ALREADY EXIST — so if someone
later restores the old layout, the path check says so rather than the task
failing mid-session.

The script is idempotent and refuses to merge into an existing destination,
so re-running it is safe.

## 4. Convert the share into the working tree

`git clone` refuses a non-empty directory, and `housing_wages/` is not
empty. Attach a repo to what is already there instead:

```powershell
cd \\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages
git init
git remote add origin github-housing:MurraySBennett/housing-decisions.git
git fetch origin
git checkout -b main --track origin/main -f
git status
```

`-f` overwrites the share's working files with the repo's. That is the
intent — they were deployed from this repo and should already match — but
**run `deploy_to_share.ps1` first anyway**, purely for its Phase 1 backup
into `Archive\`, so there is a timestamped copy if the assumption is wrong.

Expect `git status` to come back clean apart from untracked directories.
`Archive/`, `screen_recordings/`, `Experiment/Data/` and
`Experiment/stimuli/house_images/` are all gitignored, so they should not
appear. **Anything else that does appear is real divergence** — a file
edited on the lab machine that never made it back. Read it before you
discard it; that is precisely the thing this whole exercise exists to
surface.

One collision to expect: the share has `housing_wages\readme.md` and the
repo has `README.md`. Windows treats those as the same name, so the
checkout replaces it. No loss — the share copy is a stale, mojibake'd
duplicate of `experiment/stimuli/README.md` sitting at the wrong level.

## 5. From then on

At the rig, before a session:

```powershell
cd \\asc-files.asc.ohio-state.edu\projects\PSY-kvam.4\housing_wages
git pull
git status      # must be clean. If it is not, something was edited here.
```

On the dev machine, after committing: `git push`. That is the whole loop.

**Then delete `scripts/deploy_to_share.ps1`** and the `now (M)` item in
`WORK.md` that points at it. Leaving both mechanisms alive is worse than
either alone — it is how you get a share that is half-clone, half-copy and
nobody knows which files came from where.

## Giving other people access

The repo is private, so collaborators need to be added by GitHub username:

```bash
gh api -X PUT repos/MurraySBennett/housing-decisions/collaborators/<username> \
  -f permission=push      # or 'pull' for read-only
```

Worth checking whether OSU runs a GitHub Enterprise instance before
standing this on personal accounts — if it does, an org-owned repo outlives
any individual's account, which matters for a project that will be cited.

What a collaborator gets from a clone: all the code, the stimulus
definitions, `WORK.md`, and `docs/`. What they do not get: the 605 MB image
set, the Tobii SDK, and participant data. So a clone is enough to **read**
the project and to run the analysis on exported CSVs, but not enough to run
a session. That is the correct boundary.

## Known rough edges

- **Git over SMB is slow.** `git status` on this tree takes seconds, not
  milliseconds. Tolerable for pull-and-check; do not try to develop on it.
- **`index.lock`.** If two people have the share open in git at once, one
  gets a lock error. One machine, one person at a time.
- **Do not `git gc` over the share.** Repacking across SMB is slow and is
  the operation most likely to leave a half-written object.
