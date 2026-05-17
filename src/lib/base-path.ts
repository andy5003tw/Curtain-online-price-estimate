const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

function isRootRelativePath(value: string): boolean {
  return value.startsWith("/") && !value.startsWith("//");
}

export function withBasePath(path: string): string {
  if (!path || !BASE_PATH || !isRootRelativePath(path)) {
    return path;
  }
  if (path === BASE_PATH || path.startsWith(`${BASE_PATH}/`)) {
    return path;
  }
  return `${BASE_PATH}${path}`;
}

export function withBasePathInHtml(html: string): string {
  if (!html || !BASE_PATH) {
    return html;
  }

  return html.replace(
    /(href|src)=("|\')\/(?!\/)([^"']*)\2/g,
    (_match, attr: string, quote: string, rest: string) => {
      const rawPath = `/${rest}`;
      if (rawPath === BASE_PATH || rawPath.startsWith(`${BASE_PATH}/`)) {
        return `${attr}=${quote}${rawPath}${quote}`;
      }
      return `${attr}=${quote}${BASE_PATH}${rawPath}${quote}`;
    }
  );
}
