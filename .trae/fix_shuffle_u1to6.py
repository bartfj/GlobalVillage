# -*- coding: utf-8 -*-
"""一次性修复：u1-u6 旧版生成脚本未洗牌选项，正确答案恒在第一位。
用与 gen_units7to10.make_options 一致的固定种子（seed_of(ex_id)+1）补洗牌。
幂等：重复运行结果不变。"""
import hashlib
import json
import random

SRC = r'd:\workspace\github_code\地球村\assets\courses\course_beginner.json'


def seed_of(key):
    return int(hashlib.md5(key.encode()).hexdigest(), 16)


def main():
    with open(SRC, encoding='utf-8') as f:
        data = json.load(f)

    changed = 0
    for u in data['units']:
        if u['id'] not in ('u1', 'u2', 'u3', 'u4', 'u5', 'u6'):
            continue
        for l in u['lessons']:
            for e in l['exercises']:
                if e['type'] not in ('translateChoice', 'listeningChoice'):
                    continue
                # 先排序得到规范序再按固定种子洗牌，保证幂等
                opts = sorted(e['options'])
                random.Random(seed_of(e['id']) + 1).shuffle(opts)
                if opts != e['options']:
                    e['options'] = opts
                    changed += 1
                assert e['answer'] in e['options']

    with open(SRC, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=True, indent=2)

    # 校验：各单元选择题正确答案在第一位的数量
    stats = {}
    for u in data['units']:
        first = tot = 0
        for l in u['lessons']:
            for e in l['exercises']:
                if e['type'] in ('translateChoice', 'listeningChoice'):
                    tot += 1
                    if e['options'][0] == e['answer']:
                        first += 1
        stats[u['id']] = (first, tot)
    print('changed:', changed)
    print(stats)


if __name__ == '__main__':
    main()
