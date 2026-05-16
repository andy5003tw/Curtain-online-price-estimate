import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export", // Static Site Generation for deployment
  trailingSlash: true,
  images: {
    unoptimized: true, // Required for static export
  },
};

export default nextConfig;
