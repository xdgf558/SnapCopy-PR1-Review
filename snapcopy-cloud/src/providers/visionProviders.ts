import type { CloudVisionRequest, CloudVisionResponse, CloudVisionUnderstanding } from "../types/api";

export type VisionProviderEnv = {
  VISION_PROVIDER?: string;
  GLM_API_KEY?: string;
  GLM_MODEL?: string;
  GLM_BASE_URL?: string;
};

export type VisionProviderName = "mock" | "glm";

type OpenAICompatibleVisionResponse = {
  choices?: Array<{
    message?: {
      content?: string;
    };
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
  };
  error?: {
    message?: string;
  };
};

type RawVisionUnderstanding = Partial<CloudVisionUnderstanding>;

const allowedScenes = new Set([
  "breakfast",
  "cafe",
  "walking",
  "street",
  "travel",
  "pet",
  "outfit",
  "fitness",
  "sunset",
  "home",
  "work",
  "food",
  "unknown"
]);

export class VisionProviderError extends Error {
  constructor(
    message: string,
    readonly statusCode = 502
  ) {
    super(message);
    this.name = "VisionProviderError";
  }
}

export function resolveVisionProvider(env: VisionProviderEnv): VisionProviderName {
  const provider = (env.VISION_PROVIDER ?? "mock").toLowerCase();
  if (provider === "glm" || provider === "mock") {
    return provider;
  }

  return "mock";
}

export function modelForVisionProvider(provider: VisionProviderName, env: VisionProviderEnv): string {
  switch (provider) {
    case "glm":
      return env.GLM_MODEL ?? "glm-4.6v";
    case "mock":
      return "mock-vision-v1";
  }
}

export async function generateVisionUnderstanding(
  input: CloudVisionRequest,
  provider: VisionProviderName,
  env: VisionProviderEnv
): Promise<CloudVisionResponse> {
  if (provider === "mock") {
    return makeMockVisionResponse(input, provider, modelForVisionProvider(provider, env));
  }

  return generateGLMVisionUnderstanding(input, env);
}

async function generateGLMVisionUnderstanding(
  input: CloudVisionRequest,
  env: VisionProviderEnv
): Promise<CloudVisionResponse> {
  if (!env.GLM_API_KEY) {
    throw new VisionProviderError("GLM_API_KEY is not configured.", 500);
  }

  const model = modelForVisionProvider("glm", env);
  const baseUrl = (env.GLM_BASE_URL ?? "https://open.bigmodel.cn/api/paas/v4").replace(/\/+$/, "");
  const prompt = buildVisionPrompt(input);
  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.GLM_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content:
            "You are SnapCopy's cloud image-understanding engine. Return strict JSON only. Do not write captions."
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: prompt
            },
            {
              type: "image_url",
              image_url: {
                url: `data:${input.imageMimeType};base64,${input.imageBase64}`
              }
            }
          ]
        }
      ],
      temperature: 0.2,
      max_tokens: 900,
      response_format: {
        type: "json_object"
      }
    })
  });

  const json = await response.json<OpenAICompatibleVisionResponse>();
  if (!response.ok) {
    throw new VisionProviderError(providerErrorMessage("GLM", response.status, json.error?.message), 502);
  }

  const text = json.choices?.[0]?.message?.content?.trim() ?? "";
  const understanding = parseVisionUnderstandingOrThrow(text);

  return {
    understanding,
    sceneJson: mergeSceneJson(input.sceneJson, understanding, "glm", model),
    provider: "glm",
    model,
    inputTokens: json.usage?.prompt_tokens ?? 0,
    outputTokens: json.usage?.completion_tokens ?? 0,
    estimatedCost: null,
    remainingQuota: 0
  };
}

function makeMockVisionResponse(
  input: CloudVisionRequest,
  provider: VisionProviderName,
  model: string
): CloudVisionResponse {
  const localScene = extractLocalScene(input.sceneJson);
  const scene = localScene === "unknown" ? "food" : localScene;
  const understanding: CloudVisionUnderstanding = {
    scene,
    subScene: scene === "food" ? "cloud-mock-food-table" : `cloud-mock-${scene}`,
    confidence: 0.72,
    top3Scenes: [
      { scene, confidence: 0.72, reason: "Mock cloud vision keeps the local scene as the main candidate." },
      { scene: "home", confidence: 0.42, reason: "Indoor life context is plausible in mock mode." },
      { scene: "unknown", confidence: 0.2, reason: "Fallback candidate." }
    ],
    sceneTags: [scene, "cloud-vision", "mock"],
    captionFocus: `Cloud mock understanding keeps the photo grounded in the ${scene} scene.`,
    semanticSummary: `Mock cloud image understanding for ${scene}.`,
    subjectCues: [],
    objectCues: [],
    actionCues: [],
    relationshipCues: [],
    atmosphereCues: [],
    ocrTexts: [],
    mustMentionCues: [scene],
    avoidUnsupportedClaims: ["Do not invent exact objects beyond the visible/local scene evidence."]
  };

  return {
    understanding,
    sceneJson: mergeSceneJson(input.sceneJson, understanding, provider, model),
    provider,
    model,
    inputTokens: 0,
    outputTokens: 0,
    estimatedCost: 0,
    remainingQuota: 0
  };
}

function buildVisionPrompt(input: CloudVisionRequest): string {
  return [
    "Analyze the attached life photo for a social-caption app.",
    "Return only valid JSON. No Markdown. No explanation outside JSON.",
    "",
    "Allowed scene values:",
    "breakfast, cafe, walking, street, travel, pet, outfit, fitness, sunset, home, work, food, unknown",
    "",
    "JSON shape:",
    JSON.stringify(
      {
        scene: "pet",
        subScene: "cat indoors",
        confidence: 0.92,
        top3Scenes: [
          { scene: "pet", confidence: 0.92, reason: "main subject is a cat" },
          { scene: "home", confidence: 0.55, reason: "indoor room context" },
          { scene: "food", confidence: 0.2, reason: "visible tableware only if present" }
        ],
        sceneTags: ["pet", "home", "warm light"],
        captionFocus: "a cat resting in warm indoor light",
        semanticSummary: "plain-language visual summary for caption generation",
        subjectCues: ["cat"],
        objectCues: ["rug", "chair"],
        actionCues: ["resting"],
        relationshipCues: ["cat on rug"],
        atmosphereCues: ["warm light", "quiet indoor mood"],
        ocrTexts: [],
        mustMentionCues: ["cat", "warm light"],
        avoidUnsupportedClaims: ["Do not claim breed or emotion unless visible."]
      },
      null,
      2
    ),
    "",
    "Rules:",
    "- Make the scene choice product-oriented, not just raw object labels.",
    "- Use top3Scenes for uncertainty; confidence must be 0 to 1.",
    "- If the photo is a screenshot, collage, or too unclear, use unknown unless a life-photo scene is obvious.",
    "- Do not identify private people, faces, addresses, account names, or sensitive personal data.",
    "- Do not write final captions. Only return image-understanding JSON.",
    "",
    "Local app scene JSON, if available:",
    input.sceneJson ?? "{}",
    "",
    `Locale: ${input.locale}`,
    `Target platform: ${input.targetPlatform}`
  ].join("\n");
}

function parseVisionUnderstandingOrThrow(text: string): CloudVisionUnderstanding {
  const parsed = parseJsonObject(text) as RawVisionUnderstanding | null;
  if (!parsed) {
    throw new VisionProviderError("Vision provider returned invalid JSON.", 502);
  }

  const scene = normalizeScene(parsed.scene);
  const top3Scenes = (Array.isArray(parsed.top3Scenes) ? parsed.top3Scenes : [])
    .map((candidate) => ({
      scene: normalizeScene(candidate?.scene),
      confidence: normalizeConfidence(candidate?.confidence),
      reason: typeof candidate?.reason === "string" ? candidate.reason.slice(0, 240) : undefined
    }))
    .filter((candidate) => candidate.scene !== "unknown" || candidate.confidence > 0)
    .slice(0, 3);

  if (top3Scenes.length === 0) {
    top3Scenes.push({
      scene,
      confidence: normalizeConfidence(parsed.confidence),
      reason: "Primary scene returned by provider."
    });
  }

  return {
    scene,
    subScene: typeof parsed.subScene === "string" ? parsed.subScene.slice(0, 120) : null,
    confidence: normalizeConfidence(parsed.confidence),
    top3Scenes,
    sceneTags: normalizeStringArray(parsed.sceneTags, 12),
    captionFocus: typeof parsed.captionFocus === "string" ? parsed.captionFocus.slice(0, 300) : null,
    semanticSummary: typeof parsed.semanticSummary === "string" ? parsed.semanticSummary.slice(0, 600) : null,
    subjectCues: normalizeStringArray(parsed.subjectCues, 12),
    objectCues: normalizeStringArray(parsed.objectCues, 16),
    actionCues: normalizeStringArray(parsed.actionCues, 12),
    relationshipCues: normalizeStringArray(parsed.relationshipCues, 12),
    atmosphereCues: normalizeStringArray(parsed.atmosphereCues, 12),
    ocrTexts: normalizeStringArray(parsed.ocrTexts, 8),
    mustMentionCues: normalizeStringArray(parsed.mustMentionCues, 10),
    avoidUnsupportedClaims: normalizeStringArray(parsed.avoidUnsupportedClaims, 10)
  };
}

function mergeSceneJson(
  sceneJson: string | undefined,
  understanding: CloudVisionUnderstanding,
  provider: string,
  model: string
): string {
  const parsed = safeParseJson(sceneJson) as Record<string, unknown>;
  const image = (parsed.image && typeof parsed.image === "object" ? parsed.image : {}) as Record<string, unknown>;

  const existingSceneTags = Array.isArray(image.sceneTags) ? image.sceneTags.filter((tag) => typeof tag === "string") : [];
  const existingSubjectCues = Array.isArray(image.subjectCues)
    ? image.subjectCues.filter((cue) => typeof cue === "string")
    : [];
  const existingObjectCues = Array.isArray(image.objectCues)
    ? image.objectCues.filter((cue) => typeof cue === "string")
    : [];

  parsed.image = {
    ...image,
    sceneTags: uniqueStrings([understanding.scene, ...understanding.sceneTags, ...existingSceneTags]).slice(0, 16),
    primaryScene: understanding.scene,
    captionFocus: understanding.captionFocus ?? image.captionFocus ?? null,
    semanticSummary: understanding.semanticSummary ?? image.semanticSummary ?? null,
    subjectCues: uniqueStrings([...understanding.subjectCues, ...existingSubjectCues]).slice(0, 16),
    objectCues: uniqueStrings([...understanding.objectCues, ...existingObjectCues]).slice(0, 20),
    actionCues: uniqueStrings(understanding.actionCues).slice(0, 14),
    relationshipCues: uniqueStrings(understanding.relationshipCues).slice(0, 14),
    atmosphereCues: uniqueStrings(understanding.atmosphereCues).slice(0, 14),
    mustMentionCues: uniqueStrings(understanding.mustMentionCues).slice(0, 12),
    avoidUnsupportedClaims: uniqueStrings(understanding.avoidUnsupportedClaims).slice(0, 12),
    resolvedScene: {
      scene: understanding.scene,
      subScene: understanding.subScene ?? null,
      confidence: understanding.confidence,
      signals: uniqueStrings([
        `cloudVision:${provider}`,
        ...understanding.top3Scenes.map((candidate) => `${candidate.scene}:${candidate.confidence}`)
      ])
    },
    cloudVision: {
      provider,
      model,
      top3Scenes: understanding.top3Scenes,
      ocrTexts: understanding.ocrTexts
    }
  };

  return JSON.stringify(parsed);
}

function parseJsonObject(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(text.slice(start, end + 1));
      } catch {
        return null;
      }
    }

    return null;
  }
}

function safeParseJson(value: string | undefined): Record<string, unknown> {
  if (!value) {
    return {};
  }

  const parsed = parseJsonObject(value);
  return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? (parsed as Record<string, unknown>) : {};
}

function extractLocalScene(sceneJson: string | undefined): string {
  const parsed = safeParseJson(sceneJson);
  const image = parsed.image;
  if (image && typeof image === "object") {
    const imageRecord = image as Record<string, unknown>;
    if (typeof imageRecord.primaryScene === "string") {
      return normalizeScene(imageRecord.primaryScene);
    }

    const resolvedScene = imageRecord.resolvedScene;
    if (resolvedScene && typeof resolvedScene === "object") {
      const scene = (resolvedScene as Record<string, unknown>).scene;
      if (typeof scene === "string") {
        return normalizeScene(scene);
      }
    }
  }

  return "unknown";
}

function normalizeScene(value: unknown): string {
  if (typeof value !== "string") {
    return "unknown";
  }

  const normalized = value.trim().toLowerCase();
  return allowedScenes.has(normalized) ? normalized : "unknown";
}

function normalizeConfidence(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 0;
  }

  return Math.max(0, Math.min(1, Math.round(value * 1000) / 1000));
}

function normalizeStringArray(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return uniqueStrings(
    value
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter(Boolean)
      .map((item) => item.slice(0, 160))
  ).slice(0, limit);
}

function uniqueStrings(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    const normalized = value.trim();
    const key = normalized.toLowerCase();
    if (!normalized || seen.has(key)) {
      continue;
    }

    seen.add(key);
    result.push(normalized);
  }

  return result;
}

function providerErrorMessage(provider: string, status: number, message?: string): string {
  return `${provider} vision provider failed with HTTP ${status}${message ? `: ${message}` : ""}`;
}
