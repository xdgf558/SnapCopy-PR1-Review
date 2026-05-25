import { hasD1 } from "./d1Store";

export type ContributionOptimizationEnv = {
  DB?: D1Database;
  OPTIMIZATION_MIN_CAPTION_SAMPLES?: string;
  OPTIMIZATION_COOLDOWN_HOURS?: string;
  OPTIMIZATION_MAX_BUCKETS_PER_RUN?: string;
};

export type ContributionOptimizationResult = {
  storageMode: "d1" | "disabled";
  checkedBuckets: number;
  createdCandidates: number;
  skippedBuckets: number;
  threshold: number;
};

type BucketRow = {
  scene: string | null;
  locale: string | null;
  target_platform: string | null;
  sample_count: number;
  edited_count: number;
  share_count: number;
  copy_count: number;
  avg_scene_confidence: number | null;
};

type ExistingRunRow = {
  created_at: string;
};

type SampleRow = {
  caption_text: string | null;
  source: string;
  caption_was_edited: number;
  scene_tags_json: string;
  scene_confidence: number | null;
};

export async function runContributionOptimization(
  env: ContributionOptimizationEnv,
  now = new Date()
): Promise<ContributionOptimizationResult> {
  const threshold = numberFromEnv(env.OPTIMIZATION_MIN_CAPTION_SAMPLES, 200);
  const cooldownHours = numberFromEnv(env.OPTIMIZATION_COOLDOWN_HOURS, 72);
  const maxBuckets = numberFromEnv(env.OPTIMIZATION_MAX_BUCKETS_PER_RUN, 8);

  if (!hasD1(env)) {
    return {
      storageMode: "disabled",
      checkedBuckets: 0,
      createdCandidates: 0,
      skippedBuckets: 0,
      threshold
    };
  }

  const buckets = await env.DB.prepare(
    `SELECT
       COALESCE(scene, 'unknown') AS scene,
       COALESCE(locale, 'unknown') AS locale,
       COALESCE(target_platform, 'general') AS target_platform,
       COUNT(*) AS sample_count,
       SUM(CASE WHEN caption_was_edited = 1 THEN 1 ELSE 0 END) AS edited_count,
       SUM(CASE WHEN source = 'share' THEN 1 ELSE 0 END) AS share_count,
       SUM(CASE WHEN source = 'copy' THEN 1 ELSE 0 END) AS copy_count,
       AVG(scene_confidence) AS avg_scene_confidence
     FROM training_contribution_samples
     WHERE kind = 'caption'
       AND caption_text IS NOT NULL
       AND TRIM(caption_text) <> ''
     GROUP BY COALESCE(scene, 'unknown'), COALESCE(locale, 'unknown'), COALESCE(target_platform, 'general')
     HAVING COUNT(*) >= ?
     ORDER BY sample_count DESC
     LIMIT ?`
  )
    .bind(threshold, maxBuckets)
    .all<BucketRow>();

  let createdCandidates = 0;
  let skippedBuckets = 0;

  for (const bucket of buckets.results ?? []) {
    const bucketKey = bucketKeyFor(bucket.scene, bucket.locale, bucket.target_platform);
    const existing = await env.DB.prepare(
      `SELECT created_at FROM contribution_optimization_runs
       WHERE bucket_key = ?
       ORDER BY created_at DESC
       LIMIT 1`
    )
      .bind(bucketKey)
      .first<ExistingRunRow>();

    if (existing && hoursBetween(new Date(existing.created_at), now) < cooldownHours) {
      skippedBuckets += 1;
      continue;
    }

    const samples = await env.DB.prepare(
      `SELECT caption_text, source, caption_was_edited, scene_tags_json, scene_confidence
       FROM training_contribution_samples
       WHERE kind = 'caption'
         AND caption_text IS NOT NULL
         AND TRIM(caption_text) <> ''
         AND COALESCE(scene, 'unknown') = ?
         AND COALESCE(locale, 'unknown') = ?
         AND COALESCE(target_platform, 'general') = ?
       ORDER BY
         caption_was_edited DESC,
         CASE source
           WHEN 'share' THEN 3
           WHEN 'copy' THEN 2
           WHEN 'manual' THEN 1
           ELSE 0
         END DESC,
         received_at DESC
       LIMIT 80`
    )
      .bind(bucket.scene ?? "unknown", bucket.locale ?? "unknown", bucket.target_platform ?? "general")
      .all<SampleRow>();

    const summary = summarizeBucket(bucket, samples.results ?? [], threshold);
    const strategy = makeStrategyCandidate(bucket, summary, threshold);
    const runId = crypto.randomUUID();
    const candidateId = crypto.randomUUID();
    const createdAt = now.toISOString();

    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO contribution_optimization_runs (
           run_id, run_type, bucket_key, scene, locale, target_platform,
           sample_count, edited_count, share_count, copy_count, status,
           summary_json, candidate_json, created_at
         )
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(
        runId,
        "caption_strategy_candidate",
        bucketKey,
        bucket.scene,
        bucket.locale,
        bucket.target_platform,
        bucket.sample_count,
        bucket.edited_count,
        bucket.share_count,
        bucket.copy_count,
        "candidate_created",
        JSON.stringify(summary),
        JSON.stringify(strategy),
        createdAt
      ),
      env.DB.prepare(
        `INSERT INTO caption_strategy_candidates (
           candidate_id, run_id, bucket_key, scene, locale, target_platform,
           strategy_json, sample_count, confidence, status, created_at
         )
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(
        candidateId,
        runId,
        bucketKey,
        bucket.scene,
        bucket.locale,
        bucket.target_platform,
        JSON.stringify(strategy),
        bucket.sample_count,
        strategy.confidence,
        "pending_review",
        createdAt
      )
    ]);

    createdCandidates += 1;
  }

  return {
    storageMode: "d1",
    checkedBuckets: buckets.results?.length ?? 0,
    createdCandidates,
    skippedBuckets,
    threshold
  };
}

function summarizeBucket(bucket: BucketRow, samples: SampleRow[], threshold: number) {
  const captions = samples.map((sample) => sample.caption_text ?? "").filter(Boolean);
  const averageCaptionLength =
    captions.length === 0
      ? 0
      : Math.round(captions.reduce((total, caption) => total + characterLength(caption), 0) / captions.length);
  const editedRatio = ratio(bucket.edited_count, bucket.sample_count);
  const shareRatio = ratio(bucket.share_count, bucket.sample_count);
  const copyRatio = ratio(bucket.copy_count, bucket.sample_count);
  const topTags = topSceneTags(samples);

  return {
    version: "caption-optimization-summary-v1",
    scope: {
      scene: bucket.scene ?? "unknown",
      locale: bucket.locale ?? "unknown",
      targetPlatform: bucket.target_platform ?? "general"
    },
    threshold,
    sampleCount: bucket.sample_count,
    signalCounts: {
      edited: bucket.edited_count,
      shared: bucket.share_count,
      copied: bucket.copy_count
    },
    ratios: {
      edited: editedRatio,
      shared: shareRatio,
      copied: copyRatio
    },
    averageSceneConfidence: round(bucket.avg_scene_confidence ?? 0),
    averageCaptionLength,
    topSceneTags: topTags
  };
}

function makeStrategyCandidate(bucket: BucketRow, summary: ReturnType<typeof summarizeBucket>, threshold: number) {
  const promptGuidance = [
    "Write like an adult sharing a real moment, not like a template.",
    "Anchor captions in concrete visual details before adding mood.",
    lengthGuidance(summary.averageCaptionLength),
    engagementGuidance(summary.ratios.shared, summary.ratios.copied),
    editGuidance(summary.ratios.edited)
  ].filter(Boolean);

  if (summary.topSceneTags.length > 0) {
    promptGuidance.push(`When relevant, pay attention to recurring visual cues: ${summary.topSceneTags.join(", ")}.`);
  }

  return {
    version: "caption-strategy-v1",
    activation: "manual_review_required",
    confidence: strategyConfidence(bucket.sample_count, threshold, summary.ratios.shared, summary.ratios.copied),
    scope: summary.scope,
    minimumSamples: threshold,
    sampleCount: bucket.sample_count,
    signals: {
      editedRatio: summary.ratios.edited,
      shareRatio: summary.ratios.shared,
      copyRatio: summary.ratios.copied,
      averageCaptionLength: summary.averageCaptionLength,
      averageSceneConfidence: summary.averageSceneConfidence,
      topSceneTags: summary.topSceneTags
    },
    promptGuidance,
    guardrails: [
      "Do not copy user captions verbatim.",
      "Do not mention training data, user behavior, metrics, or contribution logs.",
      "If scene confidence is low, prefer grounded and modest captions over specific claims."
    ]
  };
}

function lengthGuidance(averageCaptionLength: number): string {
  if (averageCaptionLength >= 80) {
    return "This audience accepts slightly richer captions; allow one fuller sentence when the scene supports it.";
  }

  if (averageCaptionLength <= 28) {
    return "Keep captions clean and short; avoid over-explaining the moment.";
  }

  return "Use one or two natural sentences with enough detail to feel specific.";
}

function engagementGuidance(shareRatio: number, copyRatio: number): string {
  if (shareRatio + copyRatio >= 0.55) {
    return "Preserve the practical, ready-to-post tone that users tend to share or copy.";
  }

  return "Make the first option safer and more directly usable, then vary the other options.";
}

function editGuidance(editedRatio: number): string {
  if (editedRatio >= 0.3) {
    return "Users often edit this bucket; reduce generic phrasing and add more precise scene details.";
  }

  return "Avoid childish wording, exaggerated sweetness, and empty inspirational language.";
}

function strategyConfidence(sampleCount: number, threshold: number, shareRatio: number, copyRatio: number): number {
  const countScore = Math.min(0.45, (sampleCount / Math.max(threshold * 3, 1)) * 0.45);
  const actionScore = Math.min(0.4, (shareRatio + copyRatio) * 0.4);
  return round(0.15 + countScore + actionScore);
}

function topSceneTags(samples: SampleRow[]): string[] {
  const counts = new Map<string, number>();
  for (const sample of samples) {
    const tags = parseStringArray(sample.scene_tags_json);
    for (const tag of tags) {
      const cleaned = tag.trim().toLowerCase();
      if (!cleaned || cleaned.length > 32) {
        continue;
      }
      counts.set(cleaned, (counts.get(cleaned) ?? 0) + 1);
    }
  }

  return [...counts.entries()]
    .sort((left, right) => right[1] - left[1])
    .slice(0, 8)
    .map(([tag]) => tag);
}

function parseStringArray(value: string): string[] {
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === "string") : [];
  } catch {
    return [];
  }
}

function bucketKeyFor(scene: string | null, locale: string | null, targetPlatform: string | null): string {
  return [scene ?? "unknown", locale ?? "unknown", targetPlatform ?? "general"].join("|");
}

function numberFromEnv(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function hoursBetween(start: Date, end: Date): number {
  return Math.abs(end.getTime() - start.getTime()) / 3_600_000;
}

function ratio(value: number, total: number): number {
  return total > 0 ? round(value / total) : 0;
}

function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}

function characterLength(value: string): number {
  return [...value].length;
}
