/**
 * Type augmentation for vitest-axe to work with vitest 4.
 * vitest-axe@0.1.0 augments the deprecated `Vi` namespace; vitest 4 uses the `vitest` module.
 */
import 'vitest';

declare module 'vitest' {
  interface Assertion<R = unknown> {
    toHaveNoViolations(): Promise<void>;
  }
  interface AsymmetricMatchersContaining {
    toHaveNoViolations(): Promise<void>;
  }
}
