#!/usr/bin/env python3
"""
shlabs 数据库种子生成器：生成 MySQL(电商域) / PostgreSQL(HR 域) 的 init SQL。

- 每张表行数在 1~800 内随机（随机种子固定，产物可复现）
- 外键按依赖顺序生成，数据领域自洽（电商 / HR）
- 输出：database/mysql/init/02_data.sql、database/postgresql/init/02_data.sql
  （01_schema.sql 为手写结构，勿动）

用法：python3 gen_seeds.py
"""
import os
import random
from datetime import datetime, timedelta

random.seed(20260930)
HERE = os.path.dirname(os.path.abspath(__file__))
NOW = datetime(2026, 9, 30, 12, 0, 0)

# ── 数据池 ──
SURNAMES = "赵钱孙李周吴郑王冯陈褚卫沈韩杨朱秦尤许何吕施张孔曹严金魏陶姜"
GIVEN = "伟芳娜秀英敏静丽强磊军洋勇艳杰娟涛明超霞平刚桂华建文军鑫宇辰轩瑜泽琪晨浩"
CITIES = ["北京", "上海", "广州", "深圳", "杭州", "成都", "武汉", "南京", "西安", "重庆",
          "苏州", "长沙", "郑州", "青岛", "合肥", "福州", "厦门", "无锡", "宁波", "昆明"]
PROVINCES = {"北京": "北京", "上海": "上海", "广州": "广东", "深圳": "广东", "杭州": "浙江",
             "成都": "四川", "武汉": "湖北", "南京": "江苏", "西安": "陕西", "重庆": "重庆",
             "苏州": "江苏", "长沙": "湖南", "郑州": "河南", "青岛": "山东", "合肥": "安徽",
             "福州": "福建", "厦门": "福建", "无锡": "江苏", "宁波": "浙江", "昆明": "云南"}
PRODUCT_NOUNS = ["无线鼠标", "机械键盘", "降噪耳机", "显示器支架", "USB-C 扩展坞", "4K 显示器",
                 "办公椅", "升降桌", "扫描仪", "标签打印机", "网络交换机", "NAS 存储",
                 "智能音箱", "扫地机器人", "空气净化器", "电水壶", "咖啡机", "台灯",
                 "移动硬盘", "固态硬盘", "内存条", "路由器", "摄像头", "麦克风"]
BRANDS = ["极联", "速腾", "岚山", "云雀", "鲸淘", "慕思", "光年", "拓普", "青萍", "锐捷科技"]
REVIEW_GOOD = ["质量很好，物流也快", "包装严实，和描述一致", "用了一周体验不错", "性价比很高，推荐",
               "客服态度好，处理问题及时", "做工精细，比想象中好", "第二次回购了，稳定"]
REVIEW_BAD = ["做工一般，有点划痕", "物流太慢，等了十天", "和图片有色差", "噪音有点大",
              "说明书不详细", "客服响应慢"]
REVIEW_MED = ["中规中矩，符合价位", "还行，但不算惊喜", "能用，细节一般", "整体可以， minor 问题"]
DEPARTMENTS = ["研发部", "产品部", "市场部", "销售部", "人力资源部", "财务部", "运营部",
               "客服部", "法务部", "信息技术部", "质量管理部", "供应链部"]
PROJECT_WORDS = ["中台", "小程序", "数据仓库", "风控", "会员", "支付网关", "爬虫治理",
                 "监控告警", "权限中心", "报表", "国际化", "供应链"]
ASSET_TYPES = ["笔记本", "显示器", "工牌", "门禁卡", "测试手机", "扩展坞"]
REASONS = ["年假", "病假", "事假", "婚假", "调休", "产检"]
STAGES = ["简历筛选", "初面", "二面", "终面", "offer 沟通", "已入职"]
CHANNELS = ["BOSS 直聘", "内推", "拉勾", "猎头", "官网投递"]


def rand_name():
    return random.choice(SURNAMES) + "".join(random.choices(GIVEN, k=random.randint(1, 2)))


def rand_dt(start_days_ago, end_days_ago=0):
    base = NOW - timedelta(days=random.randint(end_days_ago, start_days_ago),
                           hours=random.randint(0, 23), minutes=random.randint(0, 59),
                           seconds=random.randint(0, 59))
    return base.strftime("%Y-%m-%d %H:%M:%S")


def rand_date(start_days_ago, end_days_ago=0):
    return (NOW - timedelta(days=random.randint(end_days_ago, start_days_ago))).strftime("%Y-%m-%d")


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def rand_phone():
    # 合成测试号段 1380000xxxx：形态明显非真实分配，避免随机号与真实用户撞号
    return "1380000" + "".join(random.choices("0123456789", k=4))


def gen_mysql():
    """电商域 shlabs_ecom，返回数据 SQL 文本"""
    lines = ["-- 02_data.sql：电商域种子数据（由 gen_seeds.py 生成，勿手改）",
             "SET NAMES utf8mb4;", "USE shlabs_ecom;", "SET FOREIGN_KEY_CHECKS = 0;", ""]

    # users
    users = []
    for i in range(1, 801):
        name = rand_name()
        users.append((i, f"user{i:05d}", f"user{i:05d}@example.com", rand_phone(),
                      f"$2a$10${i:08d}", name, random.choice(CITIES), rand_dt(540, 1),
                      random.choice(["active", "active", "active", "dormant"])))
    lines += ["-- 用户", "INSERT INTO users (id, username, email, phone, password_hash, nickname, city, created_at, status) VALUES"]
    lines += [f"({i}, '{esc(u)}', '{esc(e)}', '{p}', '{h}', '{esc(n)}', '{esc(c)}', '{t}', '{st}')"
              for i, u, e, p, h, n, c, t, st in users]
    lines[-1] += ";"

    # merchants
    merchants = []
    for i in range(1, 61):
        merchants.append((i, f"{random.choice(BRANDS)}{random.choice(PRODUCT_NOUNS)}专营店",
                          rand_phone(), random.choice(CITIES),
                          round(random.uniform(3.5, 5.0), 1), rand_dt(720, 90)))
    lines += ["", "-- 商户", "INSERT INTO merchants (id, name, contact_phone, city, rating, created_at) VALUES"]
    lines += [f"({i}, '{esc(n)}', '{p}', '{esc(c)}', {r}, '{t}')" for i, n, p, c, r, t in merchants]
    lines[-1] += ";"

    # categories（两级）
    top = [(i, f"{random.choice(['数码', '家居', '办公', '网络', '生活'])}电器", None) for i in range(1, 7)]
    sub = [(7 + k, f"{random.choice(['配件', '外设', '耗材'])}·{random.choice(CITIES)}仓",
            random.randint(1, 6)) for k in range(12)]
    cats = top + sub
    lines += ["", "-- 商品分类（两级）",
              "INSERT INTO categories (id, name, parent_id, sort) VALUES"]
    lines += [f"({i}, '{esc(n)}', {p if p else 'NULL'}, {i})" for i, n, p in cats]
    lines[-1] += ";"

    # products
    products = []
    for i in range(1, 641):
        title = f"{random.choice(BRANDS)} {random.choice(PRODUCT_NOUNS)} {random.choice(['标准版', 'Pro', '青春版', '旗舰款', '2026 款'])}"
        products.append((i, random.randint(1, 60), random.randint(1, 18), title,
                         round(random.uniform(19.9, 8999.0), 2), random.randint(0, 500),
                         random.randint(0, 3000), random.choice(["on_sale", "on_sale", "on_sale", "off_shelf"]),
                         rand_dt(540, 1)))
    lines += ["", "-- 商品", "INSERT INTO products (id, merchant_id, category_id, title, price, stock, sales, status, created_at) VALUES"]
    lines += [f"({i}, {m}, {c}, '{esc(t)}', {p}, {st}, {sa}, '{stat}', '{t2}')"
              for i, m, c, t, p, st, sa, stat, t2 in products]
    lines[-1] += ";"

    # product_images
    imgs = [(i, random.randint(1, 640), f"https://img.shlabs.internal/ecom/{i:06d}.webp", random.randint(1, 5))
            for i in range(1, 513)]
    lines += ["", "-- 商品图片", "INSERT INTO product_images (id, product_id, url, sort) VALUES"]
    lines += [f"({i}, {p}, '{u}', {srt})" for i, p, u, srt in imgs]
    lines[-1] += ";"

    # addresses
    addrs = []
    for i in range(1, 389):
        city = random.choice(CITIES)
        addrs.append((i, random.randint(1, 800), PROVINCES[city], city,
                      f"{random.choice(['幸福', '和平', '科技', '中山', '望京'])}路{random.randint(1, 999)}号"
                      f"{random.choice(['A 座', 'B 座', '3 栋', '5 栋'])}{random.randint(101, 2504)}室",
                      rand_name(), rand_phone(), random.choice([0, 0, 1])))
    lines += ["", "-- 收货地址", "INSERT INTO addresses (id, user_id, province, city, detail, receiver, receiver_phone, is_default) VALUES"]
    lines += [f"({i}, {u}, '{esc(pv)}', '{esc(c)}', '{esc(d)}', '{esc(r)}', '{ph}', {d_})"
              for i, u, pv, c, d, r, ph, d_ in addrs]
    lines[-1] += ";"

    # orders
    orders = []
    for i in range(1, 501):
        status = random.choice(["pending_paid", "shipped", "completed", "completed", "refunded"])
        orders.append((i, random.randint(1, 800), random.randint(1, 60), status,
                       round(random.uniform(39, 12999), 2), rand_dt(365, 1)))
    lines += ["", "-- 订单", "INSERT INTO orders (id, user_id, merchant_id, status, total_amount, created_at) VALUES"]
    lines += [f"({i}, {u}, {m}, '{st}', {amt}, '{t}')" for i, u, m, st, amt, t in orders]
    lines[-1] += ";"

    # order_items
    items = [(i, random.randint(1, 500), random.randint(1, 640),
              random.randint(1, 3), round(random.uniform(19.9, 4999.0), 2)) for i in range(1, 801)]
    lines += ["", "-- 订单明细", "INSERT INTO order_items (id, order_id, product_id, quantity, unit_price) VALUES"]
    lines += [f"({i}, {o}, {p}, {q}, {up})" for i, o, p, q, up in items]
    lines[-1] += ";"

    # payments
    pays = [(i, random.randint(1, 500),
             random.choice(["alipay", "wechat", "unionpay"]),
             round(random.uniform(39, 12999), 2), rand_dt(365, 1),
             random.choice(["success", "success", "success", "failed"])) for i in range(1, 466)]
    lines += ["", "-- 支付流水", "INSERT INTO payments (id, order_id, channel, amount, paid_at, status) VALUES"]
    lines += [f"({i}, {o}, '{c}', {a}, '{t}', '{st}')" for i, o, c, a, t, st in pays]
    lines[-1] += ";"

    # reviews
    revs = []
    for i in range(1, 721):
        pool = REVIEW_GOOD * 5 + REVIEW_BAD * 2 + REVIEW_MED * 3
        revs.append((i, random.randint(1, 800), random.randint(1, 640), random.randint(1, 500),
                     random.choice([5, 5, 4, 4, 3, 2, 1]), random.choice(pool), rand_dt(360, 1)))
    lines += ["", "-- 商品评价", "INSERT INTO reviews (id, user_id, product_id, order_id, rating, content, created_at) VALUES"]
    lines += [f"({i}, {u}, {p}, {o}, {r}, '{esc(c)}', '{t}')" for i, u, p, o, r, c, t in revs]
    lines[-1] += ";"

    # coupons
    coupons = [(i, f"SAVE{random.randint(10, 200)}-{i:03d}", round(random.choice([5, 10, 20, 50, 100]), 2),
                round(random.uniform(99, 999), 2), rand_date(30, -180)) for i in range(1, 47)]
    lines += ["", "-- 优惠券", "INSERT INTO coupons (id, code, discount, min_amount, expires_at) VALUES"]
    lines += [f"({i}, '{c}', {d}, {m}, '{e}')" for i, c, d, m, e in coupons]
    lines[-1] += ";"

    # user_coupons
    uc = [(i, random.randint(1, 800), random.randint(1, 46),
           (rand_dt(180, 1) if random.random() < 0.4 else "NULL")) for i in range(1, 334)]
    lines += ["", "-- 用户领券", "INSERT INTO user_coupons (id, user_id, coupon_id, used_at) VALUES"]
    for i, u, c, t in uc:
        t_sql = 'NULL' if t == 'NULL' else "'" + t + "'"
        lines.append(f"({i}, {u}, {c}, {t_sql})")
    lines[-1] += ";"

    # audit_logs
    logs = [(i, f"user{random.randint(1, 800):05d}",
             random.choice(["login", "password_change", "address_update", "order_create", "profile_edit"]),
             f"ip=10.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}",
             rand_dt(180, 0)) for i in range(1, 801)]
    lines += ["", "-- 审计日志", "INSERT INTO audit_logs (id, actor, action, detail, created_at) VALUES"]
    lines += [f"({i}, '{esc(a)}', '{act}', '{esc(d)}', '{t}')" for i, a, act, d, t in logs]
    lines[-1] += ";"

    lines += ["", "SET FOREIGN_KEY_CHECKS = 1;", ""]
    return "\n".join(lines)


def gen_pg():
    """HR 域 shlabs_hr，返回数据 SQL 文本"""
    lines = ["-- 02_data.sql：HR 域种子数据（由 gen_seeds.py 生成，勿手改）", ""]

    # departments
    depts = [(i, random.choice(DEPARTMENTS), random.choice(CITIES),
              round(random.uniform(50, 800), 1)) for i, _ in enumerate(DEPARTMENTS, 1)]
    depts = [(i, DEPARTMENTS[i - 1], random.choice(CITIES), round(random.uniform(50, 800), 1))
             for i in range(1, 13)]
    lines += ["-- 部门", "INSERT INTO departments (id, name, location, budget_wan) VALUES"]
    lines += [f"({i}, '{n}', '{c}', {b})" for i, n, c, b in depts]
    lines[-1] += ";"

    # employees
    emps = []
    for i in range(1, 477):
        emps.append((i, random.randint(1, 12), rand_name(), random.choice(["男", "女"]),
                     rand_date(3000, 30), f"emp{i:04d}@shlabs.example.com", rand_phone(),
                     random.randint(6, 45),
                     random.choice(["active", "active", "active", "resigned"])))
    lines += ["", "-- 员工", "INSERT INTO employees (id, dept_id, name, gender, hire_date, email, phone, salary_k, status) VALUES"]
    lines += [f"({i}, {d}, '{n}', '{g}', '{h}', '{e}', '{p}', {sk}, '{st}')"
              for i, d, n, g, h, e, p, sk, st in emps]
    lines[-1] += ";"

    # salary_records（近 24 个月按月抽样）
    sal = [(i, random.randint(1, 476), rand_date(730, 1),
            random.randint(6, 45), random.randint(0, 12), random.randint(0, 3))
           for i in range(1, 801)]
    lines += ["", "-- 薪资记录（单位 K）", "INSERT INTO salary_records (id, employee_id, pay_date, base_k, bonus_k, deduction_k) VALUES"]
    lines += [f"({i}, {e}, '{d}', {b}, {bo}, {de})" for i, e, d, b, bo, de in sal]
    lines[-1] += ";"

    # attendance（近 60 天）
    att = [(i, random.randint(1, 476), rand_date(60, 0),
            f"0{random.randint(8, 9)}:{random.randint(10, 59)}",
            f"1{random.randint(7, 9)}:{random.randint(10, 59)}",
            random.choice(["normal", "normal", "normal", "late", "remote"])) for i in range(1, 801)]
    lines += ["", "-- 考勤", "INSERT INTO attendance (id, employee_id, work_date, check_in, check_out, status) VALUES"]
    lines += [f"({i}, {e}, '{d}', '{ci}', '{co}', '{st}')" for i, e, d, ci, co, st in att]
    lines[-1] += ";"

    # leave_requests
    leaves = [(i, random.randint(1, 476), random.choice(REASONS), rand_date(365, 5),
               rand_date(365, 0), random.choice(REASONS + ["家中有事", "旅行计划"]),
               random.choice(["approved", "approved", "pending", "rejected"]),
               random.randint(1, 476)) for i in range(1, 265)]
    lines += ["", "-- 请假单", "INSERT INTO leave_requests (id, employee_id, leave_type, start_date, end_date, reason, status, approver_id) VALUES"]
    lines += [f"({i}, {e}, '{t}', '{sd}', '{ed}', '{esc(r)}', '{st}', {ap})"
              for i, e, t, sd, ed, r, st, ap in leaves]
    lines[-1] += ";"

    # performance_reviews
    revs = [(i, random.randint(1, 476), random.randint(1, 476),
             random.choice(["2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2"]),
             random.choice(["S", "A", "A", "B", "B", "C"]),
             random.choice(["超出预期，牵头关键项目", "稳定输出，协作良好", "符合预期",
                            "有提升空间，需加强交付节奏", "成长明显"])) for i in range(1, 353)]
    lines += ["", "-- 绩效评估", "INSERT INTO performance_reviews (id, employee_id, reviewer_id, quarter, grade, comment) VALUES"]
    lines += [f"({i}, {e}, {r}, '{q}', '{g}', '{esc(c)}')" for i, e, r, q, g, c in revs]
    lines[-1] += ";"

    # projects
    projs = [(i, f"{random.choice(DEPARTMENTS[:3])}{random.choice(PROJECT_WORDS)}项目{random.choice(['一期', '二期', '平台化'])}",
              random.randint(1, 12), rand_date(900, 60),
              (rand_date(300, 10) if random.random() < 0.5 else "NULL"),
              round(random.uniform(20, 600), 1)) for i in range(1, 48)]
    lines += ["", "-- 项目", "INSERT INTO projects (id, name, dept_id, start_date, end_date, budget_wan) VALUES"]
    for i, n, d, sd, ed, b in projs:
        ed_sql = 'NULL' if ed == 'NULL' else "'" + ed + "'"
        lines.append(f"({i}, '{n}', {d}, '{sd}', {ed_sql}, {b})")
    lines[-1] += ";"

    # project_members
    pm = [(i, random.randint(1, 47), random.randint(1, 476),
           random.choice(["负责人", "后端", "前端", "测试", "产品", "算法"])) for i in range(1, 190)]
    lines += ["", "-- 项目成员", "INSERT INTO project_members (id, project_id, employee_id, role) VALUES"]
    lines += [f"({i}, {p}, {e}, '{r}')" for i, p, e, r in pm]
    lines[-1] += ";"

    # job_postings
    jp = [(i, random.randint(1, 12),
           f"{random.choice(['高级', '资深', ''])}{random.choice(['后端', '前端', '测试', '算法', '产品'])}工程师",
           random.randint(1, 5), random.randint(15, 30), random.randint(30, 80),
           rand_date(240, 5), random.choice([True, False, False])) for i in range(1, 27)]
    lines += ["", "-- 招聘岗位", "INSERT INTO job_postings (id, dept_id, title, headcount, salary_min_k, salary_max_k, posted_at, closed) VALUES"]
    lines += [f"({i}, {d}, '{t}', {h}, {lo}, {hi}, '{pd}', {c})" for i, d, t, h, lo, hi, pd, c in jp]
    lines[-1] += ";"

    # candidates
    cands = [(i, random.randint(1, 26), rand_name(), random.choice(CHANNELS),
              random.choice(STAGES), rand_date(240, 1)) for i in range(1, 215)]
    lines += ["", "-- 候选人", "INSERT INTO candidates (id, posting_id, name, channel, stage, created_at) VALUES"]
    lines += [f"({i}, {p}, '{n}', '{c}', '{s}', '{d}')" for i, p, n, c, s, d in cands]
    lines[-1] += ";"

    # interviews
    ivs = [(i, random.randint(1, 214), random.randint(1, 476), rand_dt(240, 1),
            random.choice(["pass", "pass", "fail", "pending"])) for i in range(1, 159)]
    lines += ["", "-- 面试记录", "INSERT INTO interviews (id, candidate_id, interviewer_id, scheduled_at, result) VALUES"]
    lines += [f"({i}, {c}, {it}, '{t}', '{r}')" for i, c, it, t, r in ivs]
    lines[-1] += ";"

    # assets
    assets = [(i, (random.randint(1, 476) if random.random() < 0.75 else "NULL"),
               random.choice(ASSET_TYPES), f"AS-{random.randint(2023, 2026)}{i:05d}",
               rand_date(1200, 10)) for i in range(1, 319)]
    lines += ["", "-- 固定资产", "INSERT INTO assets (id, employee_id, asset_type, serial_no, assigned_at) VALUES"]
    lines += [f"({i}, {e}, '{t}', '{sn}', '{d}')" for i, e, t, sn, d in assets]
    lines[-1] += ";"

    return "\n".join(lines) + "\n"


def main():
    import re

    def write_data(path, text):
        # 多行 VALUES 的行间补逗号（行格式 "(...)" 相邻时）
        text = re.sub(r"\)\n(?=\()", "),\n", text)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)

    out = os.path.normpath(os.path.join(HERE, ".."))
    write_data(os.path.join(out, "mysql", "init", "02_data.sql"), gen_mysql())
    write_data(os.path.join(out, "postgresql", "init", "02_data.sql"), gen_pg())
    print("seeds regenerated")


if __name__ == "__main__":
    main()
