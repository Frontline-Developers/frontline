/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['<rootDir>/src/__tests__/**/*.test.ts'],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { tsconfig: 'tsconfig.test.json' }],
  },
  moduleNameMapper: {
    // Rewrite .js extension imports to .ts so Jest can find source files
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
};
