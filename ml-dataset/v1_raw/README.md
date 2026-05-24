# v1_raw

Permanent archive for the first 260 scene-training images.

Rules:

- Do not delete the 260 original images.
- Do not rename or overwrite original files.
- If the images live outside this folder, keep them there and record absolute or project-relative paths in `ml-dataset/manifests/v1_raw_manifest.csv`.
- Use `source_type` to mark `real`, `synthetic`, `screenshot`, `collage`, or `unknown`.
- If a file contains private user content, do not commit it to a public repository.

The cleaned dataset should inherit usable v1 images through `v1_clean_manifest.csv`, not by mutating files in this archive.
