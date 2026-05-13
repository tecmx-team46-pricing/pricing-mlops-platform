module.exports = async function pricingMlopsHealth(context) {
  const environment = process.env.PRICING_MLOPS_ENVIRONMENT || "unknown";
  const message = process.env.PRICING_MLOPS_HELLO_MESSAGE || "hello world";

  context.res = {
    status: 200,
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      status: "ok",
      message,
      workload: "pricing-mlops",
      environment
    })
  };
};
