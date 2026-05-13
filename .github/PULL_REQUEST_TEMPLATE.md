## Summary

<!-- What does this PR do? One paragraph max. -->

## Motivation

<!-- Why is this change needed? Link related issues with "Closes #N". -->

## Test plan

- [ ] Ran `bash agents/onboard.sh` in a throwaway directory — setup flow unbroken
- [ ] Ran `bash -n agents/<changed-scripts>` — no syntax errors
- [ ] `jq` validated any modified JSON files
- [ ] Manual smoke test described below:

<!-- Describe what you did to verify the change. -->

## Hard-rule compliance

- [ ] No `git commit` / `git push` / `gh pr merge` executed without explicit owner approval
- [ ] No AI / persona names in commit messages, file headers, or artifact content
- [ ] Commits follow Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- [ ] No secrets, tokens, or personal credentials committed

## Notes

<!-- Anything else reviewers should know (breaking changes, follow-ups, etc.). -->
