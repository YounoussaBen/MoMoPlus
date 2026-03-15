import { existsSync } from "node:fs";

async function main() {
  if (process.env.NODE_ENV === "production" || process.env.CI === "true") {
    return;
  }

  if (!existsSync("../.git")) {
    return;
  }

  process.chdir("..");

  const husky = (await import("husky")).default;
  const result = husky("web/.husky");

  if (result) {
    throw new Error(result);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
