---
applyTo: "**"
---

Keep your changes as low impact as possible. You do not need to give me a summary of changes. You do not need to test the changes. Try to reference other parts of the codebase to ensure your changes are consistent with the existing code style and practices. Keep your responses concise and focused.

Read all context and instructions carefully before making changes. Code may be manually modified between messages. Do not suggest code that has been deleted or is no longer relevant.

This project uses ruby 3.4.4 and rails 8.0.2.1. Make sure to only suggest changes that are applicable to those versions. Prefer to use the cli to generate boilerplate rather than generate it manually. You can always modify boilerplate generated from the cli.

When adding changes, use best rails & hotwire practices and patterns. Use partials and helpers to keep code DRY. Use concerns to share code between models and controllers. Use stimulus over inline javascript. Keep performance in mind and minimize database queries (e.g. use includes, avoid n+1 queries). Use background jobs for long running tasks. Use caching where appropriate. If you add the private keyword, please make sure to check nothing else is affected, as often there will be more existing code after your changes. Private methods should always be at the bottom of the class.

HCB controls money for the program, DO NOT EDIT ANY CODE RELATED TO HCB WITHOUT EXPLICIT WRITTEN APPROVAL. Alert in the chat that you're making changes to HCB code before doing so. Do not run any tests and console code containing stuff related without EXPLICIT WRITTEN APPROVAL.

When modifying code, ensure that you maintain existing functionality and do not introduce bugs. Ensure that your changes are well-integrated with the existing codebase and follow the project's coding standards and conventions. Use `git diff` to see what you changed and run checks `bin/rubocop -f github` and `bin/brakeman --no-pager` before finishing to ensure code quality and security. In those checks, if there are issues that are unrelated to your changes, you can ignore them.

If asked to change the requirements or behavior of a feature, make sure previous implementations that you suggested are also updated to reflect the new requirements.

Do not add comments unless they are absolutely necessary for clarity. Your code should describe what it does, not comments. If you do add comments, ensure they are clear, concise, and relevant to the code they accompany. Do not add huge blocks of comments.
