# Contributing to SE(3) Geodesic Master Kernel

Thank you for your interest in contributing! This document outlines how to participate in the project.

## Code of Conduct

Be respectful, inclusive, and collaborative. We follow the [Contributor Covenant](https://www.contributor-covenant.org/).

---

## Getting Started

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/SE3.git
cd SE3
git remote add upstream https://github.com/geodesic-kernel/SE3.git
```

### 2. Set Up Development Environment

```bash
# Using Stack (recommended)
stack setup
stack build --ghc-options="-O0"  # Debug build (faster)

# OR using Cabal
cabal update
cabal configure --disable-optimization
cabal build all
```

### 3. Install Development Tools

```bash
# Code formatting
stack install ormolu

# Linting
stack install hlint

# Testing framework
cabal install tasty tasty-hunit tasty-quickcheck

# Coverage analysis
cabal install hpc-lcov
```

---

## Development Workflow

### Branch Naming

```
feature/descriptive-name      # New features
bugfix/issue-description      # Bug fixes
docs/update-readme            # Documentation
perf/optimization-target      # Performance improvements
refactor/module-name          # Refactoring
```

### Before You Commit

1. **Format code:**
   ```bash
   ormolu -i $(find src test -name '*.hs')
   ```

2. **Lint:**
   ```bash
   hlint src test
   ```

3. **Run all tests:**
   ```bash
   cabal test all
   ```

4. **Check coverage:**
   ```bash
   cabal configure --enable-coverage
   cabal test all
   cabal hpc report --hpc-dir=dist-newstyle/...
   ```

### Commit Messages

```
[TYPE] Brief description (50 chars max)

Detailed explanation of changes (wrap at 72 chars).

- Bullet point 1
- Bullet point 2

Closes #123
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`

### Pull Request Process

1. **Create branch from `develop`:**
   ```bash
   git checkout -b feature/my-feature upstream/develop
   ```

2. **Develop & test:**
   ```bash
   # Make changes
   cabal test all
   ```

3. **Push to your fork:**
   ```bash
   git push origin feature/my-feature
   ```

4. **Open PR** with description of changes

5. **Address review comments** (changes auto-appear in PR)

6. **Maintainers merge** when approved

---

## Contributing Guidelines

### Code Style

**Haskell:**
- Use 2-space indentation
- Write pure functions where possible
- Document with Haddock comments
- Keep functions < 20 lines (split if needed)

```haskell
-- | Brief description (one line)
-- Longer description explaining
-- the purpose and constraints.
--
-- Example:
-- @
--   myFunction x = x + 1
-- @
myFunction :: Int -> Int
myFunction x = x + 1
```

### Testing Requirements

New features need tests:

```haskell
testCase "description of what is tested" $ do
  let input = someValue
  case myFunction input of
    Right output -> output @?= expectedValue
    Left err -> assertFailure (show err)
```

**Minimum coverage: 80%** (check with `cabal test --enable-coverage`)

### Documentation Requirements

Every public module must include:

1. **Module header:**
   ```haskell
   {-|
   Module      : Kernel.ModuleName
   Description : Brief description
   Stability   : experimental | stable | internal
   -}
   ```

2. **Exported items documentation:**
   ```haskell
   -- | What this function does
   -- | Preconditions and postconditions
   myFunction :: Type -> Type
   ```

3. **Examples in docstrings:**
   ```haskell
   -- | Usage example
   -- | @
   -- |   result <- myAsyncFunction input
   -- | @
   ```

---

## Areas for Contribution

### High Priority

- [ ] Extended unit tests (aim for >90% coverage)
- [ ] Performance benchmarks for critical paths
- [ ] Documentation of edge cases
- [ ] Hardware verification examples

### Medium Priority

- [ ] Optimizations for common operations
- [ ] Additional simulation scenarios
- [ ] Visualization tools
- [ ] Docker container setup

### Low Priority

- [ ] Language bindings (Python, Rust, etc.)
- [ ] Web interface
- [ ] Advanced visualization
- [ ] Tutorial videos

---

## Bug Reports

### Good Bug Report Includes

1. **Title:** Clear, concise description
2. **Environment:** GHC version, OS, Stack/Cabal version
3. **Reproduction steps:**
   ```bash
   cabal test unit-tests
   # [Error message here]
   ```
4. **Expected vs. Actual:** What should happen vs. what did
5. **Minimal example:**
   ```haskell
   -- Smallest code that reproduces the issue
   myBuggyFunction x = ...
   ```

### Bug Report Template

```markdown
## Environment
- GHC: 9.2.8
- Cabal: 3.8.1.0
- OS: Linux 5.15.x

## Steps to Reproduce
1. Run `cabal test unit-tests`
2. Filter test: "test/unit/Test/Manifold.hs"
3. Observe error

## Expected Behavior
Manifold projection should preserve orthogonality

## Actual Behavior
Orthogonality constraint violated: dot = 0.23

## Minimal Reproduction
```haskell
let r = Quaternion (Scalar32 65536) ...
let d = Quaternion (Scalar32 16384) ...
case projectSE3Safe (DualQuaternion r d) of
  Right _ -> putStrLn "Success"
  Left err -> putStrLn $ show err
```

## Possible Fix
Could be related to saturation in qScale operation
```

---

## Feature Requests

### Good Feature Request Includes

1. **Motivation:** Why is this needed?
2. **Proposed solution:** How should it work?
3. **Alternatives considered:** Other approaches?
4. **Use case:** Concrete example

---

## Performance Optimization

### Profiling

```bash
# Build with profiling
cabal configure --enable-profiling
cabal build exe:playground --ghc-options="-O2 +RTS -p -RTS"

# Analyze results
ghc-events show playground.eventlog
```

### Common Hotspots

In order of optimization priority:

1. **Quaternion multiplication** (~40% of time)
   ```haskell
   -- Current
   qMul q1 q2 = ...  -- 16 multiplications
   
   -- Optimized (fewer muls)
   qMul q1 q2 = ... 
   ```

2. **Manifold projection** (~30%)
3. **Saturation checks** (~20%)
4. **Error handling** (~10%)

### Optimization Checklist

- [ ] Profile with `cabal bench`
- [ ] Identify bottleneck (>5% of time)
- [ ] Implement improvement
- [ ] Verify correctness with tests
- [ ] Benchmark comparison
- [ ] Document assumption/tradeoff

---

## Documentation

### Updating README

- [ ] Changes reflected in setup instructions
- [ ] API examples still work
- [ ] Theory section updated if needed
- [ ] Version numbers updated

### Adding Examples

Place in `examples/` with:

1. **Clear naming:** `examples/feature-description.hs`
2. **Documentation:** Comments explaining physics
3. **Runnable:** `cabal run example -- --help`
4. **Tests:** Verify output in CI

---

## Review Process

### What Reviewers Look For

✅ **Good:**
- Clear commit messages
- Tests included
- Documentation updated
- Follows code style
- Addresses feedback constructively

❌ **Will Request Changes:**
- Missing tests
- Undocumented public APIs
- Commits too large (>400 lines)
- Breaking changes without explanation

### How to Handle Feedback

1. Don't take it personally (we're critiquing code, not you!)
2. Ask clarifying questions if needed
3. Make suggested changes
4. Re-push (auto-updates PR)
5. Thank reviewers

---

## Releasing

### Release Checklist

- [ ] Bump version in `.cabal` file
- [ ] Update CHANGELOG.md
- [ ] All tests passing on main branch
- [ ] Documentation up to date
- [ ] Haddock builds without warnings
- [ ] Tag with version: `git tag v1.0.0`

### Release Process

```bash
# On main branch
cabal configure
cabal sdist
cabal upload dist-newstyle/sdist/*.tar.gz

# GitHub release (via web UI)
```

---

## Questions?

- **Discussions:** https://github.com/geodesic-kernel/SE3/discussions
- **Issues:** https://github.com/geodesic-kernel/SE3/issues
- **Email:** dev@geodesic-kernel.local

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

**Thank you for making this project better!** 🚀
