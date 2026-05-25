import type { CloudCaptionRequest } from "../types/api";

export function buildCaptionProviderPrompt(input: CloudCaptionRequest): string {
  const language = languageName(input.locale);
  const platform = platformGuidance(input.targetPlatform);
  const payload = {
    sceneJson: safeParseJson(input.sceneJson),
    userPreferenceJson: safeParseJson(input.userPreferenceJson ?? "{}"),
    targetPlatform: input.targetPlatform,
    locale: input.locale,
    language,
    platformGuidance: platform
  };

  return [
    "You are SnapCopy's senior social caption writer.",
    "The app did not upload the original photo. You only receive structured scene analysis JSON and user preference JSON.",
    "Write captions that feel natural, adult, specific, and suitable for a real social post.",
    "",
    "Strict rules:",
    "- Return only valid JSON. No Markdown. No explanations.",
    "- JSON shape: {\"captions\":[\"caption 1\",\"caption 2\",\"caption 3\",\"caption 4\",\"caption 5\"]}.",
    "- Write exactly 5 captions.",
    `- Write every caption in ${language}.`,
    "- Do not mention JSON, AI, labels, confidence, OCR, model analysis, or scene metadata.",
    "- Do not invent details that are not supported by the scene JSON.",
    "- Use concrete visual cues from sceneJson when available: objects, light, place, mood, OCR text, colors, composition.",
    "- Avoid generic templates like 'ordinary day' unless the scene is truly unknown.",
    "- Vary the 5 options: at least one warm, one concise, one slightly playful, and one premium-polished caption.",
    "- Keep captions ready to share; no numbering inside the caption text.",
    "",
    `Platform guidance: ${platform}`,
    "",
    "Input payload:",
    JSON.stringify(payload, null, 2)
  ].join("\n");
}

function safeParseJson(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function languageName(locale: string): string {
  const normalized = locale.toLowerCase();
  if (normalized.includes("ja")) {
    return "Japanese";
  }

  if (normalized.includes("en")) {
    return "English";
  }

  if (normalized.includes("hant")) {
    return "Traditional Chinese";
  }

  return "Simplified Chinese";
}

function platformGuidance(platform: string): string {
  switch (platform.toLowerCase()) {
    case "xiaohongshu":
      return "Xiaohongshu: polished, tasteful, shareable, concrete details, light emoji only when natural; avoid clickbait.";
    case "wechat":
      return "WeChat Moments: warm, life-like, friendly, suitable for people who know the user; avoid salesy wording.";
    case "instagram":
      return "Instagram: visual, concise, slightly stylish, mood-forward, suitable for photo-first sharing.";
    case "x":
      return "X: concise, sharp, conversational, no long hashtags.";
    default:
      return "General social platform: natural, concrete, easy to post.";
  }
}
