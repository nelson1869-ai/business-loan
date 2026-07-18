# Lesson 4 - VS Code Workspace

## Objective

Create a consistent Flutter development workspace with PowerShell as the main terminal.

## Completed work

- [x] Added `.vscode/settings.json`.
- [x] Set PowerShell as the default Windows terminal.
- [x] Set new terminals to open at the workspace root.
- [x] Enabled Dart formatting and explicit save actions.
- [x] Set the Dart line length to 100 characters.
- [x] Enabled Flutter hot reload on save.
- [x] Configured Flutter DevTools behavior.
- [x] Excluded generated build folders from search and file watching.
- [x] Enabled Material Icon Theme and editor visual guides.
- [x] Added `.vscode/extensions.json`.

## Recommended extensions

| Extension | Purpose |
| --- | --- |
| Dart | Dart language support, analysis, formatting, and debugging |
| Flutter | Flutter commands, device selection, hot reload, and debugging |
| PowerShell | PowerShell editing and terminal support |
| Markdownlint | Markdown quality checks |
| Markdown All in One | Markdown authoring tools |
| Material Icon Theme | Clear file and folder icons |

## Student setup

1. Open the repository folder in VS Code.
2. Open **Extensions** with `Ctrl+Shift+X`.
3. Enter `@recommended` in the extension search box.
4. Review and install the recommended extensions.
5. Open a new terminal and confirm that it uses PowerShell.

## Verification commands

```powershell
Get-Location
flutter doctor -v
flutter devices
```
