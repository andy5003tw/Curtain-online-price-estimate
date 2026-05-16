import type { NextConfig } from "next";

const repoName = process.env.GITHUB_REPOSITORY?.split("/")[1] ?? "";
const isGitHubActionsBuild = process.env.GITHUB_ACTIONS === "true";
const ghPagesPrefix = isGitHubActionsBuild && repoName ? `/${repoName}` : "";

const nextConfig: NextConfig = {
  output: "export", // Static Site Generation for deployment
  trailingSlash: true,
  assetPrefix: ghPagesPrefix || undefined,
  images: {
    unoptimized: true, // Required for static export
  },
};

export default nextConfig;
