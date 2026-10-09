# 药灵童子治疗声（新版已选，旧版备用）

- A：`../v1/wav/herbal_spirit_child_attack.wav`，之前的0.48秒治疗声，保持不变；另存完整副本 `healer_old_backup.wav`，方便以后换回。
- B：`healer_new_full.wav`，LilMati的Powerup 07完整0.904762秒声音，仅降约11.73dB使峰值与A接近（约-12dBFS），不是感知响度匹配。未裁剪、变调、变速或叠加。
- 打开 `index.html` 分别试听。负责人已选择B新版，A旧版保留备用；采用文件及校验见 `selection.json`，由06后续完成运行接入。
- 来源：https://freesound.org/people/LilMati/sounds/523649/ ，CC0 1.0：https://creativecommons.org/publicdomain/zero/1.0/ （2026-10-09核对）；可商用和改编，无强制署名要求，保留来源追溯。
- 保存的源为公开HQ MP3预览，非需登录下载的原始WAV；转WAV不提升原始质量。
- 复现：`python3 tools/prepare.py`（需要numpy）。源解码文件在source，处理参数及哈希见manifest.json。
- 已检查格式、时长、无削波、源/旧版哈希、复现结果及页面音频链接；未做人工听感或游戏内验收。
