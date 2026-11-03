# Contributing to Grimreach

Grimreach is a personal fantasy-world project. You are welcome to read, fork,
experiment, play, report problems, and suggest ideas. The code and repository
assets are available under the [MIT license](LICENSE).

## Coordinate before coding for this repository

The owner accepts pull requests only from people invited as repository
collaborators. Anyone can fork the public code and open an issue to discuss a
bug, idea, or possible contribution. An invitation gives access to open a PR;
it does not reserve a task or promise a merge.

Before starting work intended for this repository:

1. Search open issues and PRs for the same change.
2. Open an issue using the relevant template, or comment on the existing issue.
   State the outcome and the part you would like to work on.
3. Wait for the owner to confirm the scope and coordination if another person
   may be working in the same area. The issue is the shared place for progress.
4. If invited, work in your fork or an issue branch and link your PR to the
   issue. Keep it focused and describe what you tested.

You can still explore and publish your own fork without an invitation. Please
do not put credentials, tunnel tokens, private player data, or someone else's
assets into issues or PRs.

## Local checks

The server uses Go 1.24. The native client uses Godot 4.7.2. Run `go test ./...`
and `go vet ./...` for Go changes. Run relevant scripts under `client/tests`
with `godot --headless --path client --script res://tests/<name>.gd` for client
changes. See the [README](README.md) for local server and export instructions.

The `develop` branch integrates current work. The owner reviews promotion to
`main`; please target `develop` unless the owner directs otherwise. Both
branches require PRs. If your change affects behavior, update the relevant
documentation and explain any validation you could not perform.

## Sponsorship

Support and sponsorship are welcome. A Sponsor button will be added when the
owner provides an active funding destination. In the meantime, useful issue
reports, play feedback, and thoughtful proposals help the project.
