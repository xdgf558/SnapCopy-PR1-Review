import type { ContributionImageMimeType, ContributionStorageMode, TrainingContributionSampleRequest } from "../types/api";

export type R2Env = {
  TRAINING_IMAGES?: R2Bucket;
};

export type TrainingImageStorageResult = {
  storageMode: ContributionStorageMode;
  objectKey: string | null;
  mimeType: ContributionImageMimeType | null;
  width: number | null;
  height: number | null;
  byteSize: number | null;
  sha256: string | null;
  privacyRedactionStatus: string;
};

const extensionByMimeType: Record<ContributionImageMimeType, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp"
};

export async function storeTrainingImageIfPresent(
  env: R2Env,
  input: TrainingContributionSampleRequest
): Promise<TrainingImageStorageResult> {
  if (!input.imageUploadEnabled || !input.imageBase64 || !input.imageMimeType) {
    return {
      storageMode: "d1-metadata-only",
      objectKey: null,
      mimeType: null,
      width: input.imageWidth ?? null,
      height: input.imageHeight ?? null,
      byteSize: null,
      sha256: input.imageSha256 ?? null,
      privacyRedactionStatus: "metadata_only"
    };
  }

  if (!env.TRAINING_IMAGES) {
    return {
      storageMode: "d1-r2-not-configured",
      objectKey: null,
      mimeType: input.imageMimeType,
      width: input.imageWidth ?? null,
      height: input.imageHeight ?? null,
      byteSize: null,
      sha256: input.imageSha256 ?? null,
      privacyRedactionStatus: "compressed_image_not_stored_r2_missing"
    };
  }

  const bytes = decodeBase64Image(input.imageBase64);
  const sha256 = input.imageSha256 ?? (await sha256Hex(bytes));
  const createdDate = safeDate(input.createdAt);
  const dateKey = createdDate.toISOString().slice(0, 10);
  const scene = safePathSegment(input.scene ?? "unknown");
  const extension = extensionByMimeType[input.imageMimeType];
  const objectKey = `training-contributions/${dateKey}/${input.kind}/${scene}/${input.sampleId}.${extension}`;

  await env.TRAINING_IMAGES.put(objectKey, bytes, {
    httpMetadata: {
      contentType: input.imageMimeType
    },
    customMetadata: {
      appUserId: input.appUserId,
      sampleId: input.sampleId,
      consentId: input.consentId,
      kind: input.kind,
      scene,
      locale: input.locale,
      targetPlatform: input.targetPlatform ?? "unknown",
      privacy: "user_consented_compressed_copy_no_original"
    }
  });

  return {
    storageMode: "d1-r2-compressed-image",
    objectKey,
    mimeType: input.imageMimeType,
    width: input.imageWidth ?? null,
    height: input.imageHeight ?? null,
    byteSize: bytes.byteLength,
    sha256,
    privacyRedactionStatus: "user_consented_compressed_copy_no_original"
  };
}

function decodeBase64Image(base64: string): Uint8Array {
  const cleanBase64 = base64.includes(",") ? base64.slice(base64.indexOf(",") + 1) : base64;
  const binary = atob(cleanBase64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function safeDate(value: string): Date {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? new Date() : date;
}

function safePathSegment(value: string): string {
  const normalized = value.toLowerCase().replace(/[^a-z0-9_-]/g, "-").replace(/-+/g, "-");
  return normalized.replace(/^-|-$/g, "") || "unknown";
}
