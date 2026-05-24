# Synthetic Hard Case Prompt Pack

Use these prompts only to supplement the dataset. Synthetic images should not become the dataset majority.

Recommended v2 ratio:

- Real photos: 65% to 80%
- AI-generated photos: 20% to 35%
- Special source images: 5% to 10%
- Extreme hard cases: below 30% of the total dataset

All generated images should look like ordinary phone photos, not polished advertising images.

## Prompt Pattern

Use this pattern and replace `{scene}` and `{hard_case}`:

```text
A realistic casual iPhone photo for the SnapCopy scene classifier.
Scene: {scene}.
Hard case: {hard_case}.
Style: everyday life, natural phone snapshot, not commercial, not studio lighting.
Avoid: logos, readable private information, celebrity faces, explicit content, over-polished stock-photo look.
Output: one image only.
```

## Scene Prompts

### breakfast

- Normal: breakfast plate on a morning table, eggs, bread, coffee, soft daylight, casual phone photo.
- low_light: breakfast on a dim kitchen table under warm indoor light.
- blurry: slightly shaky breakfast table photo with eggs and toast still recognizable.
- partial_subject: half-visible coffee cup and plate edge on a morning table.
- cluttered: busy breakfast table with dishes, napkins, and food packaging.
- screenshot: phone screenshot of a breakfast photo inside a gallery view.

### cafe

- Normal: coffee cup on a cafe table with indoor cafe background.
- low_light: latte on a small cafe table in dim evening light.
- partial_subject: cropped coffee cup and table corner with cafe interior hints.
- weird_angle: close low-angle shot of a coffee cup on a table.
- text_overlay: cafe photo with small date text overlay.
- compressed: low-resolution cafe table photo with visible compression artifacts.

### walking

- Normal: casual walking photo of path, trees, sidewalk, everyday outdoor route.
- blurry: motion-blurred sidewalk and trees while walking.
- weird_angle: tilted phone photo of a path and shoes while walking.
- partial_subject: only part of a path, rail, and trees visible.
- low_light: evening walk photo with street lamps.
- cluttered: busy park path with signs, bikes, and people in the distance.

### street

- Normal: city street with buildings, road, and urban space.
- low_light: night street with lights and buildings.
- backlight: street scene facing bright sky, buildings slightly dark.
- overexposed: sunny street with some washed-out highlights.
- screenshot: map or social screenshot containing a street photo.
- collage: two or four small street photos in one collage.

### travel

- Normal: tourist viewpoint at a landmark, hotel, airport, train station, or scenic place.
- weird_angle: tilted travel snapshot at a scenic viewpoint.
- partial_subject: cropped suitcase and station sign, travel context visible.
- low_light: hotel or airport travel photo at night.
- cluttered: tourist scene with bags, signs, and crowds.
- text_overlay: travel photo with date/location text overlay.

### pet

- Normal: cat or dog as the main subject in a home or outdoor scene.
- low_light: cat in a dim room, subject still recognizable.
- blurry: slightly blurry dog or cat moving.
- partial_subject: half-visible cat body or dog face.
- cluttered: pet among furniture, blankets, toys, or household objects.
- weird_angle: overhead or floor-level pet snapshot.

### outfit

- Normal: mirror selfie or clothing-focused photo.
- low_light: indoor outfit mirror photo with dim room light.
- partial_subject: cropped outfit showing jacket, bag, or shoes.
- cluttered: outfit photo with messy bedroom background.
- text_overlay: outfit screenshot from gallery or social app with overlay text.
- backlight: outfit photo near a bright window.

### fitness

- Normal: gym, running, yoga, or workout equipment photo.
- blurry: motion-blurred running or gym photo.
- low_light: dim gym equipment photo.
- partial_subject: cropped yoga mat, shoes, or dumbbell.
- cluttered: gym bag, bottle, shoes, and workout equipment mixed together.
- screenshot: fitness app screenshot containing a workout photo.

### sunset

- Normal: sunset or dusk sky as the main subject.
- overexposed: bright sunset sky with washed highlights.
- backlight: foreground dark, sky orange and bright.
- blurry: slightly shaky sunset phone photo.
- collage: multiple sunset photos in one grid.
- text_overlay: sunset photo with timestamp or caption overlay.

### home

- Normal: home room, bed, sofa, kitchen corner, or everyday living space.
- low_light: dim living room or bedroom photo.
- cluttered: messy room corner with furniture and objects.
- partial_subject: only part of a sofa, bed, or table is visible.
- weird_angle: overhead or tilted room snapshot.
- compressed: low-resolution home photo with noise.

### work

- Normal: desk, laptop, monitor, keyboard, notebook, or office scene.
- low_light: dim desk setup with laptop glow.
- cluttered: busy work desk with cables, notes, cups, and devices.
- partial_subject: cropped keyboard and notebook.
- screenshot: screenshot of a desk photo or productivity app with desk image.
- text_overlay: work desk photo with calendar/time text overlay.

### food

- Normal: non-breakfast food, restaurant dish, dinner, dessert, or snack.
- low_light: restaurant food photo in dim lighting.
- blurry: slightly shaky plate of food.
- partial_subject: cropped plate edge or fork with food.
- cluttered: table with many dishes and utensils.
- overexposed: white plate food photo with bright highlights.

### unknown

- Normal: image with no clear main scene, mixed content, abstract shape, or unrelated screenshot.
- blurry: severely unclear but realistic phone photo.
- collage: mixed collage with several unrelated photos.
- screenshot: chat/gallery/social screenshot where scene is not the main subject.
- text_overlay: mostly text with unclear photo context.
- cluttered: mixed objects where no single class should win.
