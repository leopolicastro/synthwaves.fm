# Contributing

Thanks for your interest in contributing to synthwaves.fm!

## Setup

**Requirements:** Ruby 4.0.1+, SQLite3, ffmpeg

```bash
bin/setup
```

This installs dependencies, prepares the database, and starts the dev server.

## Development

```bash
bin/dev              # Start dev server
bin/rspec            # Run tests
bundle exec standardrb  # Lint
```

## Submitting Changes

1. Open an issue first for large changes so we can discuss the approach
2. Fork the repo and create a branch from `main`
3. Include tests for new behavior
4. Make sure `bin/rspec` and `bundle exec standardrb` pass
5. Open a pull request

## Reporting Bugs

Open an issue with steps to reproduce, expected behavior, and actual behavior.
