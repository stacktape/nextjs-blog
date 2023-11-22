/** @type {import('next').NextConfig} */
const nextConfig = {
  outputFileTracingExcludes: {
    '*': ['@swc/core', 'esbuild', 'uglify-js', 'watchpack', 'webassemblyjs', 'sharp']
  }
};

module.exports = nextConfig;
