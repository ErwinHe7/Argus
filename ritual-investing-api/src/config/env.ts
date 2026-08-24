import { z } from "zod";

const httpsUrl = z.string().url().refine((value) => value.startsWith("https://"), {
  message: "must use https",
});

export const environmentSchema = z
  .object({
    ENVIRONMENT: z.enum(["development", "test", "staging", "production"]),
    API_ORIGIN: z.string().url(),
    AUTH0_ISSUER: httpsUrl.refine((value) => value.endsWith("/"), {
      message: "must end with a slash",
    }),
    AUTH0_AUDIENCE: httpsUrl,
  })
  .strip();

export type Bindings = z.infer<typeof environmentSchema>;

export function validateBindings(input: unknown): Bindings {
  return environmentSchema.parse(input);
}
