const autocannon = require("autocannon");

const origin = "https://blableblu.lambda-url.eu-west-1.on.aws/"; // Replace with your target origin

// Run autocannon with the specified options and callback function
autocannon(
  { url: origin, connections: 100, duration: 60, pipelining: 10 },
  (err, res) => console.log(JSON.stringify(res)) // or save to file, it is up to you
);
