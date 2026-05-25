export function parseCaptionsFromProviderText(text: string): string[] {
  const jsonText = extractJson(text);
  const parsed = tryParseJson(jsonText);
  const captions = captionsFromParsedValue(parsed);

  if (captions.length > 0) {
    return normalizeCaptions(captions);
  }

  return normalizeCaptions(
    text
      .replace(/```json|```/gi, "")
      .split(/\n+/)
      .map((line) => line.replace(/^\s*[-*\d.)\]]+\s*/, "").trim())
      .filter(Boolean)
  );
}

function extractJson(text: string): string {
  const trimmed = text.trim().replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/\s*```$/i, "");

  if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
    return trimmed;
  }

  const firstObject = trimmed.indexOf("{");
  const lastObject = trimmed.lastIndexOf("}");
  if (firstObject >= 0 && lastObject > firstObject) {
    return trimmed.slice(firstObject, lastObject + 1);
  }

  const firstArray = trimmed.indexOf("[");
  const lastArray = trimmed.lastIndexOf("]");
  if (firstArray >= 0 && lastArray > firstArray) {
    return trimmed.slice(firstArray, lastArray + 1);
  }

  return trimmed;
}

function tryParseJson(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return undefined;
  }
}

function captionsFromParsedValue(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.filter((item): item is string => typeof item === "string");
  }

  if (!value || typeof value !== "object") {
    return [];
  }

  const objectValue = value as Record<string, unknown>;
  const captions = objectValue.captions;
  if (Array.isArray(captions)) {
    return captions.filter((item): item is string => typeof item === "string");
  }

  return [];
}

function normalizeCaptions(captions: string[]): string[] {
  const seen = new Set<string>();
  const normalized: string[] = [];

  for (const caption of captions) {
    const cleaned = caption.replace(/\s+/g, " ").trim();
    if (!cleaned || seen.has(cleaned)) {
      continue;
    }

    seen.add(cleaned);
    normalized.push(cleaned);
    if (normalized.length === 5) {
      break;
    }
  }

  return normalized;
}
