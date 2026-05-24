import type { CloudCaptionRequest } from "../types/api";

export function makeMockCaptions(input: CloudCaptionRequest): string[] {
  const context = input.sceneJson.toLowerCase();

  if (context.includes("cafe") || context.includes("coffee")) {
    return [
      "把节奏先放慢一点，今天从这杯咖啡开始。",
      "咖啡在手，忙碌也可以有一点松弛。",
      "给自己留一段不被打扰的咖啡时间。",
      "这一口，是今天的小小缓冲区。",
      "先坐下来，再和今天慢慢交手。"
    ];
  }

  if (context.includes("pet") || context.includes("cat") || context.includes("dog")) {
    return [
      "它只是出现一下，生活就变得有表情了。",
      "今天的主角很清楚自己有多会抢镜。",
      "有些陪伴不用说话，也很有存在感。",
      "这一幕很日常，但刚好让人想留下。",
      "被它看一眼，今天就自动柔软一点。"
    ];
  }

  if (context.includes("food") || context.includes("breakfast")) {
    return [
      "认真吃饭，也是把今天照顾好的一种方式。",
      "这一餐不负责隆重，只负责把人安顿下来。",
      "生活的秩序，有时候就藏在一顿饭里。",
      "先把胃照顾好，其他事慢慢来。",
      "这一口，是今天很具体的满足感。"
    ];
  }

  if (context.includes("travel") || context.includes("street") || context.includes("walking")) {
    return [
      "走到这里的时候，刚好想把这一刻留下。",
      "路上的风景不一定盛大，但很适合慢慢看。",
      "今天的坐标，交给这张照片来记。",
      "出门走走，才发现日常也会换一种光。",
      "把脚步放慢一点，城市会露出更多细节。"
    ];
  }

  if (context.includes("work")) {
    return [
      "把事情一件件理顺，今天也算稳稳推进。",
      "桌面不一定完美，但状态正在慢慢上线。",
      "认真工作的时候，也要给自己留一点呼吸感。",
      "今天的进度，就从这个角落开始。",
      "把注意力收回来，事情就会一点点清楚。"
    ];
  }

  return [
    "这一刻没有太多解释，但值得被留下。",
    "普通的一天，也会有刚好想记录的瞬间。",
    "把眼前这一点生活感，先收进照片里。",
    "不必很特别，刚好真实就很好。",
    "今天的小片段，替我保存一下。"
  ];
}
