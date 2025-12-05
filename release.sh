#!/bin/bash

# 检查是否传入了参数，默认为 patch
TYPE=${1:-patch} 

# 1. 检查 git 状态，确保干净
if [[ -n $(git status -s) ]]; then
    echo "❌ Git 工作区不干净，请先提交或 stash 更改。"
    exit 1
fi

echo "🚀 开始发布流程，升级类型: $TYPE"

# 2. 使用 cider 提升版本号并自动增加构建号 (+1)
# 这一步会修改 pubspec.yaml
NEW_VERSION=$(cider bump $TYPE --bump-build)

echo "✅ 版本号已更新为: $NEW_VERSION"

# 3. (可选) 更新 CHANGELOG.md
# cider log "Release $NEW_VERSION"

# 4. 提交更改
git add pubspec.yaml
# 如果有 changelog 也要 add
# git add CHANGELOG.md 
git commit -m "chore(release): bump version to $NEW_VERSION"

# 5. 打 Tag
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo "🎉 版本发布完成！"
echo "👉 请运行: git push && git push --tags"
