import { z } from 'astro/zod';
import rawRelease from './release.json';

export const releaseSchema = z.object({
  version: z.string().regex(/^\d+\.\d+\.\d+$/),
  fileSize: z.string().min(1),
  minimumMacOS: z.string().min(1),
  architectures: z.array(z.enum(['arm64', 'x86_64'])).min(1),
  architectureLabel: z.string().min(1),
  architectureShortLabel: z.string().min(1),
  downloadURL: z.url(),
  releaseURL: z.url(),
  checksumURL: z.url(),
  sha256: z.string().regex(/^[a-f0-9]{64}$/),
  earlyAccess: z.boolean(),
  notarized: z.boolean(),
  signature: z.string().min(1),
});

export type ReleaseMetadata = z.infer<typeof releaseSchema>;
export const releaseMetadata: ReleaseMetadata = releaseSchema.parse(rawRelease);
