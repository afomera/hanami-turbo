# Changelog

## Unreleased

- Initial release.
- Add `button_to`, for one-button forms with Turbo confirmations (`data: {turbo_confirm: "..."}`).
- Support custom stream actions: include a module into `Hanami::Turbo::StreamBuilder`. Actions may have no target, and `turbo_stream_action_tag` matches turbo-rails.
