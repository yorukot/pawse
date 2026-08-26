import { releaseMetadata } from '../data/release';

export const prerender = true;

export function GET() {
  return new Response(`${JSON.stringify(releaseMetadata, null, 2)}\n`, {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  });
}
