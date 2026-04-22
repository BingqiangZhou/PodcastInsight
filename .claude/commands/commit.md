---
name: /commit
description: Smart commit workflow - analyze changes and generate conventional commit messages
usage: /commit [type]
example: /commit or /commit feat
---

# Smart Commit Workflow Command

When receiving `/commit [type]` command, follow these steps:

## Step 1: Analyze Changes
1. Run `git status` to see all changed files
2. Run `git diff` to see specific changes
3. Distinguish between staged and unstaged changes

## Step 2: Determine Commit Type
Auto-detect type based on changes (if user not specified):
- `test` - Test file changes
- `doc` - Documentation changes
- `chore` - Build, config, dependency related
- `feat` - New feature (default)
- `fix` - Bug fix
- `refactor` - Code refactoring
- `style` - Code style adjustments
- `perf` - Performance optimization

## Step 3: Determine Scope
Infer scope from file paths:
- `auth` - Authentication related
- `podcast` - Podcast related
- `chat` - Chat related
- `settings` - Settings related
- `user` - User related
- `api` - API related
- `models` - Data models related
- `services` - Service layer related
- `core` - Core functionality
- `ui` - UI components

## Step 4: Generate Commit Message
Follow [Conventional Commits](https://www.conventionalcommits.org/) format:
```
<type>[optional scope]: <summary>

<bullet list of changes>
```

The commit message must include:
1. **Summary line**: One-line description in `<type>[optional scope]: <summary>` format
2. **Body bulleted list**: Each significant change listed as a separate bullet point

### Commit Message Structure:
```
<type>[optional scope]: <summary>

- <Bullet point 1>

- <Bullet point 2>

- <Bullet point 3>
...
```

### Bullet Point Format:
- Start with capital letter
- Use imperative mood ("Add", "Fix", "Move", not "Adds", "Fixed", "Moving")
- Be specific and concise
- No period at the end
- Maximum 80 characters per line

### Example:
```
refactor(podcast): restructure simplified episode card layout and add widget tests

- Move play/add to queue buttons to bottom row with metadata

- Reorganize card to show title, description, then actions

- Add proper test keys for widget testing

- Fix RefreshIndicator placement in episodes page

- Add textScaler to RichText in list page

- Add new widget test for simplified episode card layout
```

## Step 5: Wait for Confirmation
1. Display generated commit message
2. Ask user to confirm
3. Cancel if not accepted

## Step 6: Execute Commit
1. If unstaged changes exist, run `git add` first
2. Execute `git commit`
3. Display commit result

**IMPORTANT**: Do NOT include `Co-Authored-By:` in commit messages.

## Commit Message Format Reference
Based on project `cliff.toml` commit_parsers:

| Pattern | Group |
|---------|-------|
| `^feat` | 🚀 Features |
| `^fix` | 🐛 Bug Fixes |
| `^doc` | 📚 Documentation |
| `^perf` | ⚡ Performance |
| `^refactor` | 🚜 Refactor |
| `^style` | 🎨 Styling |
| `^test` | 🧪 Testing |
| `^chore` | ⚙️ Miscellaneous Tasks |

## Examples

### Example 1:
Input: `/commit`
- Analyze changes: `frontend/lib/features/podcast/...`
- Auto-detect type: `refactor`
- Auto-detect scope: `podcast`
- Generate:
```
refactor(podcast): restructure desktop player position and update player visibility logic

- Move desktop player from bottomNavigationBar to right pane bottom

- Update player visibility logic for transcript/summary tabs on mobile

- Add scroll-to-top button positioning adjustment above mini player

- Change spacer background color from transparent to surface

- Add LayoutBuilder wrapper for wide layout detection

- Improve title layout in simplified episode card with fixed two-line slot

- Add extensive widget tests for new player behavior
```
- Execute commit after confirmation

### Example 2:
Input: `/commit test`
- Specified type: `test`
- Generate:
```
test(podcast): add widget tests for desktop player positioning

- Verify desktop player is constrained to right content area bottom

- Test player visibility on transcript and summary tabs when expanded

- Validate scroll-to-top button positioning above mini player

- Add tests for mobile player visibility on transcript/summary tabs
```

### Example 3:
Input: `/commit feat`
- Analyze changes: `frontend/lib/features/settings/...`
- Generate:
```
feat(settings): add markdown rendering to update dialog

- Implement markdown rendering in update_dialog.dart

- Add markdown support in app_update_provider.dart

- Update error handling for markdown parsing failures
```
