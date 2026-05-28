export function parseCaptionsFromProviderText(text: string): string[] {
  const cleanedText = stripCodeFences(text);
  const jsonText = extractJson(cleanedText);
  const parsed = tryParseJson(jsonText);
  const captions = captionsFromParsedValue(parsed);

  if (captions.length > 0) {
    return normalizeCaptions(captions);
  }

  const repairedCaptions = captionsFromMalformedCaptionsArray(cleanedText);
  if (repairedCaptions.length > 0) {
    return normalizeCaptions(repairedCaptions);
  }

  return normalizeCaptions(
    cleanedText
      .split(/\n+/)
      .map((line) => cleanLooseCaptionLine(line))
      .filter(Boolean)
  );
}

function stripCodeFences(text: string): string {
  return text.trim().replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/\s*```$/i, "");
}

function extractJson(text: string): string {
  const trimmed = text.trim();

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
    return captionsFromArray(value);
  }

  if (!value || typeof value !== "object") {
    return [];
  }

  const objectValue = value as Record<string, unknown>;
  const captions = objectValue.captions;
  if (Array.isArray(captions)) {
    return captionsFromArray(captions);
  }

  for (const key of ["data", "result", "output"]) {
    const nested = objectValue[key];
    const nestedCaptions = captionsFromParsedValue(nested);
    if (nestedCaptions.length > 0) {
      return nestedCaptions;
    }
  }

  return [];
}

function captionsFromArray(value: unknown[]): string[] {
  return value.flatMap((item) => {
    if (typeof item === "string") {
      return [item];
    }

    if (!item || typeof item !== "object") {
      return [];
    }

    const objectValue = item as Record<string, unknown>;
    for (const key of ["text", "caption", "content", "body"]) {
      const text = objectValue[key];
      if (typeof text === "string") {
        return [text];
      }
    }

    return [];
  });
}

function captionsFromMalformedCaptionsArray(text: string): string[] {
  const match = text.match(/["']?captions["']?\s*:\s*\[([\s\S]*)/i);
  if (!match) {
    return [];
  }

  const afterOpenBracket = match[1] ?? "";
  const arrayBody = afterOpenBracket.includes("]")
    ? afterOpenBracket.slice(0, afterOpenBracket.lastIndexOf("]"))
    : afterOpenBracket;
  const parsedArray = tryParseJson(`[${arrayBody}]`);
  const parsedCaptions = captionsFromParsedValue(parsedArray);
  if (parsedCaptions.length > 0) {
    return parsedCaptions;
  }

  return quotedStringsFrom(arrayBody);
}

function quotedStringsFrom(value: string): string[] {
  const strings: string[] = [];
  const pattern = /"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)'/g;
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(value)) !== null) {
    const raw = match[1] ?? match[2] ?? "";
    const decoded = decodeJsonString(raw);
    if (decoded) {
      strings.push(decoded);
    }
  }

  return strings;
}

function decodeJsonString(value: string): string {
  try {
    return JSON.parse(`"${value.replace(/"/g, '\\"')}"`);
  } catch {
    return value;
  }
}

function cleanLooseCaptionLine(line: string): string {
  const withoutListPrefix = line.replace(/^\s*[-*\d.)\]]+\s*/, "").trim();
  const textValue = withoutListPrefix.match(/^["']?(?:text|caption|content|body)["']?\s*:\s*(.+)$/i)?.[1];
  const candidate = textValue ?? withoutListPrefix;
  const cleaned = candidate
    .replace(/,$/, "")
    .trim()
    .replace(/^["'`]+/, "")
    .replace(/["'`]+$/, "")
    .trim();

  return isLikelyCaptionText(cleaned) ? cleaned : "";
}

function normalizeCaptions(captions: string[]): string[] {
  const seen = new Set<string>();
  const normalized: string[] = [];

  for (const caption of captions) {
    const cleaned = caption.replace(/\s+/g, " ").trim().replace(/^["'`]+|["'`,]+$/g, "").trim();
    if (!isLikelyCaptionText(cleaned) || seen.has(cleaned)) {
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

function isLikelyCaptionText(text: string): boolean {
  const cleaned = text.trim();
  if (cleaned.length < 2) {
    return false;
  }

  if (/^[{}\[\],]+$/.test(cleaned)) {
    return false;
  }

  if (/^["']?captions?["']?\s*:?\s*\[?\s*,?$/i.test(cleaned)) {
    return false;
  }

  if (/^["']?[a-zA-Z_][\w-]*["']?\s*:\s*[\[{]?[,]?$/.test(cleaned)) {
    return false;
  }

  const normalized = cleaned
    .toLowerCase()
    .replace(/["'`，。,.()[\]{}_\-\s]/g, "");
  const metadataTokens = new Set([
    "style",
    "platform",
    "length",
    "lengthlevel",
    "emojilevel",
    "emoji",
    "scene",
    "healing",
    "humor",
    "premium",
    "xiaohongshu",
    "concise",
    "poetic",
    "daily",
    "general",
    "wechat",
    "instagram",
    "short",
    "medium",
    "long",
    "none",
    "light",
    "food",
    "street",
    "travel",
    "pet",
    "work",
    "unknown"
  ]);

  return !metadataTokens.has(normalized);
}
