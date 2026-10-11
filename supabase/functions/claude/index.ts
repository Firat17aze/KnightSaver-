// The app's only way to reach Claude. The Anthropic API key lives in this function's
// secrets (`ANTHROPIC_API_KEY`), never in the app or the repository.
//
// The app sends the Messages API fields it needs (system, messages, tools, output_config,
// max_tokens). This function checks that a KnightSaver user is signed in, picks the model,
// caps the request, and returns Claude's message JSON unchanged.
import Anthropic from "npm:@anthropic-ai/sdk@0.133.0";

const MODEL = Deno.env.get("CLAUDE_MODEL") ?? "claude-haiku-5-5";
const MAX_TOKENS = 16_000;
// Enough for one resized photo plus a conversation.
const MAX_BODY_BYTES = 2_000_000;
// One EcoKnight conversation, including tool rounds.
const MAX_MESSAGES = 80;

const anthropic = new Anthropic(); // Reads ANTHROPIC_API_KEY.

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// The app's error parser reads `message`.
function fail(status: number, message: string): Response {
  return json(status, { message });
}

// True when the bearer token belongs to a signed-in Supabase user of this project.
async function isSignedIn(req: Request): Promise<boolean> {
  const authorization = req.headers.get("Authorization") ?? "";
  const apikey = req.headers.get("apikey") ?? "";
  if (!authorization.startsWith("Bearer ") || !apikey) return false;
  const response = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey },
  });
  if (!response.ok) return false;
  const user = await response.json();
  return typeof user?.id === "string";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail(405, "Use POST.");
  if (!(await isSignedIn(req))) return fail(401, "Sign in to use KnightSaver AI.");

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return fail(413, "That request is too large.");

  let input: Record<string, unknown>;
  try {
    input = JSON.parse(raw);
  } catch {
    return fail(400, "The request isn't valid JSON.");
  }

  const { system, messages, tools, output_config, max_tokens } = input ?? {};
  if (typeof system !== "string" || !Array.isArray(messages) || messages.length === 0) {
    return fail(400, "Send a system prompt and at least one message.");
  }
  if (messages.length > MAX_MESSAGES) return fail(400, "This conversation is too long. Start a new one.");
  if (tools !== undefined && !Array.isArray(tools)) return fail(400, "tools must be a list.");

  try {
    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: Math.min(Number(max_tokens) || MAX_TOKENS, MAX_TOKENS),
      system,
      messages,
      ...(tools ? { tools } : {}),
      ...(output_config ? { output_config } : {}),
    } as Anthropic.MessageCreateParamsNonStreaming);
    return json(200, message);
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      return fail(429, "KnightSaver AI is busy. Try again in a moment.");
    }
    if (error instanceof Anthropic.APIError) {
      console.error("Claude API error", error.status, error.message);
      return fail(502, `KnightSaver AI couldn't answer (Claude error ${error.status ?? "unknown"}).`);
    }
    console.error("Unexpected error", error);
    return fail(500, "KnightSaver AI couldn't answer.");
  }
});
