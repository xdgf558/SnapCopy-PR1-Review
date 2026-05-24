# SnapCopy TestFlight 测试说明

## 本版重点测试

1. 从相册选择照片后，能看到图片预览。
2. 直接拍照后，能回到 App 并生成文案。
3. 点击“生成文案”后，能得到适合当前照片的文案。
4. 切换发布平台：通用、小红书、朋友圈、Instagram、X 后，生成语气会随平台变化。
5. 切换文案长度：简短、自然、详细后，生成字数会跟着变化。
6. 点击“不喜欢，换一条”后，能换出另一条文案，并逐步避开类似表达。
7. 点击“复制”和“分享”后，文字内容能正确进入剪贴板或分享面板。
8. 点击“收藏”后，文案能出现在“历史与收藏”页；取消收藏后会从收藏筛选里消失。
9. 在“历史与收藏”页，确认历史文案可以复制、分享、删除。
10. 选择照片后，上方图片预览和“图片风格”保持固定，下方发布平台、文案长度、生成结果可以独立滚动。
11. 选择照片后，点击“照片理解诊断”，确认能看到 Vision 标签、confidence、OCR、产品特征、scene/subScene、Prompt 和原始模型返回；Prompt 应以单一 `photo_context_json` 为核心。
12. 用 12 类照片验证诊断结果：早餐、咖啡、散步街景、旅行风景、宠物、穿搭、健身、日落、室内生活、工作桌面、餐厅食物、模糊或难识别照片。
13. 当场景置信度低于 75% 时，确认界面会提示建议手动选择场景。
14. 当场景置信度低于 45% 时，确认不直接生成最终文案，会要求先选择场景方向。
15. 在设置里切换界面语言和文案语言后，App 文案能正确变化。
16. 在支持 Apple Foundation Models 的真机上，优先验证本机 AI 生成效果。
17. 免费版每日生成额度为 100 次，测试时一般不需要删除重装来恢复次数。

## 暂未开放

- 系统相册 Share Extension 暂时移除，请先从 App 内相册或拍照入口导入图片。
- Pro 创作图和云端增强模式只预留框架，暂未接入外部大模型 API。
- 订阅、付费墙和正式商业化。

## 反馈格式

请尽量附上这些信息，方便复现：

- 机型：
- iOS 版本：
- SnapCopy 版本：
- 操作步骤：
- 实际结果：
- 期望结果：
- 截图或录屏：

反馈邮箱：yehao1105@gmail.com

## App Store Connect Beta App Review Notes

SnapCopy is a photo caption assistant. This beta build tests photo library selection, camera capture, a fixed photo preview area with independently scrolling caption controls, image analysis diagnostics with Vision labels/confidence/OCR/scene inference, structured JSON context prompts for on-device caption generation with Apple Foundation Models when available, low-confidence scene fallback prompts, platform-specific caption templates, caption length controls, caption copy/share, local caption history, favorites, interface language switching, and caption language preference. The Pro creative image and cloud enhancement frameworks are reserved but no external model API is connected. The system Share Extension is temporarily removed from this build; users should import photos from inside the app. In-app purchases are not enabled in this build.
