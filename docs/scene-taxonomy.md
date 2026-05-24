# SnapCopy Scene Taxonomy

This document defines the 13 local scene classes used by SnapCopy's on-device image classifier.

The goal is product usefulness, not academic object recognition. Choose the label that best helps the app write a social caption.

## Label List

1. breakfast
2. cafe
3. walking
4. street
5. travel
6. pet
7. outfit
8. fitness
9. sunset
10. home
11. work
12. food
13. unknown

## breakfast

Breakfast scenes. Common elements include breakfast plates, coffee, bread, eggs, pancakes, croissants, morning table setups, and light morning meals.

Use `breakfast` when the photo is mainly about a morning meal.

Common confusion:

- `breakfast` vs `cafe`: if the focus is a breakfast meal, use `breakfast`; if the focus is cafe atmosphere, coffee table, or shop interior, use `cafe`.
- `breakfast` vs `food`: if the meal clearly looks like breakfast or brunch, use `breakfast`; otherwise use `food`.

## cafe

Coffee shop, cafe table, latte, espresso, coffee cup, cafe interior, bakery counter, or coffee-focused atmosphere.

Use `cafe` when the mood is primarily coffee/cafe, even if there is light food.

Common confusion:

- `cafe` vs `breakfast`: cafe atmosphere wins when coffee shop context is strong.
- `cafe` vs `food`: if the photo is a cafe drink/table mood, use `cafe`; if the food dish is the subject, use `food`.

## walking

Photos taken while walking: roadside, trees, sidewalks, riverside paths, park trails, shoes-on-the-ground snapshots, and casual daily observations in motion.

Use `walking` when the image feels like a personal walking record.

Common confusion:

- `walking` vs `street`: use `walking` if the photo implies movement or a personal route; use `street` if it mainly documents the city/street itself.
- `walking` vs `travel`: ordinary paths are not travel unless there is clear tourist or destination context.

## street

Urban street scenes: roads, buildings, city blocks, traffic, architecture, storefronts, and general city space.

Use `street` when there is no strong personal walking, outfit, or travel intent.

Common confusion:

- `street` vs `walking`: street itself wins when the photo is about the environment.
- `street` vs `travel`: do not label ordinary streets as `travel` unless the tourist/destination context is clear.
- `street` vs `outfit`: if a person/clothing is clearly the main subject, use `outfit`.

## travel

Travel destinations, hotels, airports, trains, stations, landmarks, beaches, mountains, scenic viewpoints, luggage, tourist perspective, and vacation context.

Use `travel` only when there is clear travel intent.

Common confusion:

- `travel` vs `street`: a normal city street is `street`, not `travel`.
- `travel` vs `sunset`: if the photo is mainly sunset sky, use `sunset`; if it is a travel landscape with sunset as atmosphere, use `travel`.

## pet

Cats, dogs, or other pets as the main subject.

Use `pet` when the pet is visually important or emotionally central.

Common confusion:

- If a pet is tiny in the background, do not automatically use `pet`.
- If a pet appears with food, use `pet` when the pet is the subject; use `food` only when the food is the clear subject.
- Pet screenshots or memes with unclear real-life context may be `unknown`.

## outfit

Outfit photos, mirror selfies, clothing display, shoes, bags, fashion details, or full-body personal style shots.

Use `outfit` when the photo is mainly about what someone is wearing.

Common confusion:

- `outfit` vs `street`: if clothing/person is the subject, use `outfit`; if the street is the subject, use `street`.
- `outfit` vs `home`: mirror selfies at home are still `outfit` when clothing is the focus.

## fitness

Gym scenes, workout equipment, running, yoga, exercise records, sports gear, dumbbells, mats, treadmills, and training environments.

Use `fitness` when the photo supports a workout or health caption.

Common confusion:

- `fitness` vs `outfit`: workout clothing alone can be `outfit`; visible exercise context makes it `fitness`.
- `fitness` vs `walking`: casual walking paths are `walking`; exercise tracking/running scenes are `fitness`.

## sunset

Sunset, dusk, twilight, orange/pink sky, evening glow, and dramatic sky as the main subject.

Use `sunset` when the sky/light is the photo's subject.

Common confusion:

- `sunset` vs `travel`: travel location with a sunset may be `travel` if the landmark/scenic destination dominates; otherwise `sunset`.
- `sunset` vs `street`: if sunset is only background and the city/street is main, use `street`.

## home

Home life, bed, sofa, bedroom, living room, kitchen, room corners, furniture, quiet indoor daily life.

Use `home` when the photo is a living space or domestic moment.

Common confusion:

- `home` vs `work`: a desk with laptop/keyboard/notebook usually becomes `work`; a sofa/bed/room corner is `home`.
- `home` vs `pet`: if a pet is the main subject, use `pet`.
- `home` vs `food`: kitchen or table context may still be `food` if the dish is the subject.

## work

Computer, laptop, monitor, keyboard, notebook, documents, office desk, meeting setup, productivity context.

Use `work` when the photo should trigger a work/study/productivity caption.

Common confusion:

- `work` vs `home`: home office photos are `work` when desk/computer/work tools dominate.
- `work` vs `unknown`: screenshots of software without a clear physical scene may be `unknown` unless they clearly represent work.

## food

Non-breakfast food, restaurant dishes, dinner, lunch, dessert, snacks, drinks where the dish is the focus.

Use `food` when the image is mainly about eating or a dish and not specifically breakfast/cafe.

Common confusion:

- `food` vs `breakfast`: breakfast/brunch cues go to `breakfast`.
- `food` vs `cafe`: cafe atmosphere and coffee focus go to `cafe`.
- `food` vs `pet`: a pet eating or posing with food is `pet` if the pet is the emotional subject.

## unknown

Images where the scene cannot be confidently assigned: severe blur, abstract images, pure screenshots, mixed collages, unclear subjects, irrelevant images, or multiple classes with no dominant subject.

Use `unknown` when forcing a class would hurt caption quality.

Important:

- Do not make `unknown` only garbage images.
- Include realistic ambiguous photos, screenshots, collages, and mixed scenes users may actually upload.
- Use `unknown` for pure UI screenshots unless a real-life photo scene is clearly central.
