/** @type {import("@commitlint/types").UserConfig} */
export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "body-empty": [2, "never"],
    "body-max-line-length": [2, "always", 200],
  },
};
