import tsPlugin from "@typescript-eslint/eslint-plugin";
import importX from "eslint-plugin-import-x";
import prettierConfig from "eslint-config-prettier";
import globals from "globals";

export default [
  {ignores: ["lib/**/*", "eslint.config.mjs"]},
  ...tsPlugin.configs["flat/recommended"],
  importX.flatConfigs.recommended,
  {
    languageOptions: {
      parserOptions: {
        project: ["tsconfig.json", "tsconfig.eslint.json"],
        sourceType: "module",
      },
      globals: {...globals.es6, ...globals.node},
    },
    rules: {
      "import-x/no-unresolved": "off",
    },
  },
  prettierConfig,
];
