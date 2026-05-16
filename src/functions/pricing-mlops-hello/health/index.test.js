const assert = require("node:assert/strict");
const health = require("./index");

async function main() {
  process.env.PRICING_MLOPS_ENVIRONMENT = "sandbox-local";
  process.env.PRICING_MLOPS_HELLO_MESSAGE = "hello world";

  const context = {};
  await health(context, {});

  assert.equal(context.res.status, 200);
  assert.equal(context.res.headers["Content-Type"], "application/json");

  const body = JSON.parse(context.res.body);
  assert.equal(body.status, "ok");
  assert.equal(body.message, "hello world");
  assert.equal(body.workload, "pricing-mlops");
  assert.equal(body.environment, "sandbox-local");

  console.log("pricing-mlops hello function OK");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
