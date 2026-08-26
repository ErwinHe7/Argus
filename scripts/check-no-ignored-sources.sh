#!/usr/bin/env bash
#
# 防止 .gitignore 的按目录名匹配规则（data/ reports/ outputs/ logs/ build/ ...）
# 再次吞掉源码目录。
#
# 事故回顾：`data/` 这条规则匹配仓库里任何层级的 data 目录，包括
#   axio7-model-review/source/quant_engine_rs/src/data/
#   axio7-model-review/source/intraday_quant/src/intraday_quant/data/
# `reports/` 吞掉了
#   axio7-model-review/source/intraday_quant/src/intraday_quant/reports/
# 三个目录整体没进仓库，Rust 编译不过、Python 无法 collection，
# 而本地 dirty worktree 一切正常，问题在推送后才暴露。
#
# 本脚本在**本地**运行时最有价值（源码文件还在工作区里），
# 建议挂成 pre-commit hook：
#   ln -s ../../scripts/check-no-ignored-sources.sh .git/hooks/pre-commit
#
# 在 CI 里它是兜底：clean checkout 中被吞掉的文件根本不存在，
# 真正的 CI 防线是「从 clean checkout 能否构建」那几个 job。

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# 需要保护的源码树。新增语言/子项目时在这里追加。
source_globs=(
  "axio7-model-review/source/quant_engine_rs/src"
  "axio7-model-review/source/quant_engine_rs/tests"
  "axio7-model-review/source/intraday_quant/src"
  "axio7-model-review/source/intraday_quant/tests"
  "axio7-model-review/source/quant_core_cpp/src"
  "axio7-model-review/source/quant_core_cpp/include"
  "axio7-model-review/source/quant_core_cpp/apps"
  "axio7-model-review/source/quant_core_cpp/tests"
  "ritual-investing-api/src"
  "ritual-investing-api/test"
  "ritual-investing-api/scripts"
  "ritual-investing-api/drizzle"
  "ritual-investing-api/compatibility"
  "ritual-investing-api/ops"
  "ritual-investing-api-client/lib"
  "ritual-investing-api-client/test"
  "ritual-investing-api-client/templates"
  "ritual-investing-app/lib"
  "ritual-investing-app/test"
  "ritual-investing-app/integration_test"
  "ritual-investing-admin/lib"
  "ritual-investing-admin/test"
  "ritual-investing-admin/integration_test"
  "ritual-investing-admin/test_driver"
  "ritual-investing-admin/web"
)

violations=""
for tree in "${source_globs[@]}"; do
  [ -d "$tree" ] || continue
  # 列出源码树下所有真实存在的文件，问 git 哪些会被忽略。
  # 构建产物与缓存本来就该被忽略，从结果里剔除，否则全是噪音。
  while IFS= read -r path; do
    case "$path" in
      */__pycache__/*|*.pyc|*/target/*|*/build/*|*/.pytest-tmp*/*|*/.venv/*) continue ;;
      *.egg-info/*|*/.mypy_cache/*|*/.ruff_cache/*) continue ;;
    esac
    violations+="$path"$'\n'
  done < <(find "$tree" -type f -print 2>/dev/null | git check-ignore --stdin || true)
done

if [ -n "$violations" ]; then
  echo "错误：以下源码文件会被 .gitignore 排除，提交后仓库将无法构建：" >&2
  echo "$violations" | sed '/^$/d' | sed 's/^/  /' >&2
  echo "" >&2
  echo "修复方式：在 .gitignore 里为对应目录加 ! 放行规则。" >&2
  echo "注意 git 无法重新包含被排除目录内部的文件，只能重新包含目录本身，" >&2
  echo "所以放行规则必须以 / 结尾指向目录，例如 '!**/src/**/data/'。" >&2
  exit 1
fi

echo "OK：所有受保护源码树中没有被 gitignore 的文件。"
