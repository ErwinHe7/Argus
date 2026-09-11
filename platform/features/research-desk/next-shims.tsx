import React from 'react';
export function Link({ children, href, ...props }: React.AnchorHTMLAttributes<HTMLAnchorElement>) {
  return <a href={href} {...props}>{children}</a>;
}
export function Image({ src, alt, width, height, ...props }: React.ImgHTMLAttributes<HTMLImageElement>) {
  return <img {...props} src={src === '/brand/leo-lion.png' ? '/app/research-desk/lion.png' : src} alt={alt ?? ''} width={width} height={height} />;
}
