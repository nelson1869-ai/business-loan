# Lesson 3 - Git Repository

## Objective

Place the project under version control and connect it to its GitHub repository.

## Completed work

- [x] Initialized Git in `D:\Development\lending_nelson`.
- [x] Set `main` as the primary branch.
- [x] Added the remote named `origin`.
- [x] Configured the GitHub repository URL.
- [x] Created the initial project commit.

## Verified repository details

| Item | Value |
| --- | --- |
| Branch | `main` |
| Remote name | `origin` |
| Remote URL | `https://github.com/nelson1869-ai/business-loan.git` |
| Initial commit | `b88bf47 Initial Flutter project setup` |

## Commands used

```powershell
git init
git branch -M main
git remote add origin https://github.com/nelson1869-ai/business-loan.git
git add .
git commit -m "Initial Flutter project setup"
```

## Verification commands

```powershell
git status
git branch --show-current
git remote -v
git log --oneline -5
```

> The local branch is configured to track `origin/main`. Remote push status was not
> independently verified when this lesson was written.
