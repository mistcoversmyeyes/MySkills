#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LeetCode 题目信息获取脚本

用法:
    python fetch_problem.py <problem_id>
    python fetch_problem.py --slug <title_slug>
    python fetch_problem.py --file <path_to_cpp_file>

示例:
    python fetch_problem.py 49
    python fetch_problem.py --file ~/.leetcode/49.字母异位词分组.cpp
"""

import sys
import os
import re
import json
import argparse
import subprocess
from typing import Dict, Any, Optional


def parse_problem_id_from_file(filepath: str) -> Optional[str]:
    """
    从 LeetCode 题目文件中解析题号

    Args:
        filepath: .cpp/.py/.java 文件路径

    Returns:
        题号字符串，如果解析失败返回 None
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # 匹配 @lc app=leetcode.cn id=49 或类似格式
        match = re.search(r'@lc\s+app=leetcode\.cn\s+id=(\d+)', content)
        if match:
            return match.group(1)

        # 从文件名提取题号 (如 "49.字母异位词分组.cpp")
        filename = os.path.basename(filepath)
        match = re.match(r'(\d+)\.', filename)
        if match:
            return match.group(1)

        return None

    except Exception as e:
        print(f"[WARNING] 无法解析文件: {e}", file=sys.stderr)
        return None


def fetch_using_leetcode_cli(problem_id: str) -> Optional[Dict[str, Any]]:
    """
    使用 leetcode-cli (如果已安装) 获取题目信息

    Args:
        problem_id: 题号

    Returns:
        题目信息字典，失败返回 None
    """
    try:
        # 检查是否安装了 leetcode-cli
        result = subprocess.run(
            ["leetcode", "info", str(problem_id), "-x"],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            # 尝试解析 JSON 输出
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                pass

        return None

    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def format_simple_problem_info(problem_id: str, title: str = "") -> str:
    """
    格式化简单的题目信息（当 API 不可用时）

    Args:
        problem_id: 题号
        title: 题目标题（可选）

    Returns:
        Markdown 格式的基本信息
    """
    lines = []

    if title:
        lines.append(f"## {problem_id}. {title}")
    else:
        lines.append(f"## 题目 {problem_id}")

    lines.append("")
    lines.append("[题目描述待补充 - 请手动从 LeetCode 网站获取]")
    lines.append("")
    lines.append("LeetCode 链接: ")
    if title:
        lines.append(f"- 中文站: https://leetcode.cn/problems/{title.lower().replace(' ', '-')}/")
    lines.append(f"- 国际站: https://leetcode.com/problems/problem-{problem_id}/")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="获取 LeetCode 题目信息")
    parser.add_argument("problem_id", nargs="?", help="LeetCode 题号")
    parser.add_argument("--slug", help="题目的 title slug")
    parser.add_argument("--file", help="从题目文件解析题号")
    parser.add_argument("--title", help="题目标题（用于离线模式）")

    args = parser.parse_args()

    # 确定题号
    problem_id = args.problem_id
    title = args.title

    if args.file:
        problem_id = parse_problem_id_from_file(args.file)
        if not problem_id:
            print("[ERROR] 无法从文件中解析题号", file=sys.stderr)
            sys.exit(1)

    if not problem_id:
        parser.print_help()
        sys.exit(1)

    # 尝试使用 leetcode-cli
    question_data = fetch_using_leetcode_cli(problem_id)

    if question_data:
        print(json.dumps(question_data, ensure_ascii=False, indent=2))
    else:
        # 降级到简单模式
        print(format_simple_problem_info(problem_id, title or ""))
        print("[INFO] API 请求失败，请手动补充题目描述", file=sys.stderr)


if __name__ == "__main__":
    main()