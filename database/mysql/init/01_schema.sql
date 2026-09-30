-- shlabs_ecom：电商域（MySQL 8.x）
-- 首次初始化由 docker-entrypoint 自动执行；02_data.sql 为生成种子数据，勿手改

SET NAMES utf8mb4;

CREATE TABLE users (
    id            INT UNSIGNED PRIMARY KEY,
    username      VARCHAR(32)  NOT NULL UNIQUE,
    email         VARCHAR(128) NOT NULL UNIQUE,
    phone         VARCHAR(16)  NOT NULL,
    password_hash VARCHAR(64)  NOT NULL,
    nickname      VARCHAR(32)  NOT NULL,
    city          VARCHAR(32)  NOT NULL,
    created_at    DATETIME     NOT NULL,
    status        ENUM('active','dormant','banned') NOT NULL DEFAULT 'active',
    KEY idx_users_city (city),
    KEY idx_users_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE merchants (
    id            INT UNSIGNED PRIMARY KEY,
    name          VARCHAR(64) NOT NULL,
    contact_phone VARCHAR(16) NOT NULL,
    city          VARCHAR(32) NOT NULL,
    rating        DECIMAL(2,1) NOT NULL DEFAULT 4.5,
    created_at    DATETIME    NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE categories (
    id        INT UNSIGNED PRIMARY KEY,
    name      VARCHAR(64) NOT NULL,
    parent_id INT UNSIGNED NULL,
    sort      INT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE products (
    id          INT UNSIGNED PRIMARY KEY,
    merchant_id INT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    title       VARCHAR(128) NOT NULL,
    price       DECIMAL(10,2) NOT NULL,
    stock       INT NOT NULL DEFAULT 0,
    sales       INT NOT NULL DEFAULT 0,
    status      ENUM('on_sale','off_shelf') NOT NULL DEFAULT 'on_sale',
    created_at  DATETIME NOT NULL,
    KEY idx_products_merchant (merchant_id),
    KEY idx_products_category (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE product_images (
    id         INT UNSIGNED PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    url        VARCHAR(255) NOT NULL,
    sort       INT NOT NULL DEFAULT 0,
    KEY idx_images_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE addresses (
    id             INT UNSIGNED PRIMARY KEY,
    user_id        INT UNSIGNED NOT NULL,
    province       VARCHAR(32) NOT NULL,
    city           VARCHAR(32) NOT NULL,
    detail         VARCHAR(255) NOT NULL,
    receiver       VARCHAR(32) NOT NULL,
    receiver_phone VARCHAR(16) NOT NULL,
    is_default     TINYINT NOT NULL DEFAULT 0,
    KEY idx_addresses_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE orders (
    id           INT UNSIGNED PRIMARY KEY,
    user_id      INT UNSIGNED NOT NULL,
    merchant_id  INT UNSIGNED NOT NULL,
    status       ENUM('pending_paid','shipped','completed','refunded') NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    created_at   DATETIME NOT NULL,
    KEY idx_orders_user (user_id),
    KEY idx_orders_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_items (
    id         INT UNSIGNED PRIMARY KEY,
    order_id   INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    quantity   INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    KEY idx_items_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payments (
    id       INT UNSIGNED PRIMARY KEY,
    order_id INT UNSIGNED NOT NULL,
    channel  ENUM('alipay','wechat','unionpay') NOT NULL,
    amount   DECIMAL(12,2) NOT NULL,
    paid_at  DATETIME NOT NULL,
    status   ENUM('success','failed') NOT NULL,
    KEY idx_payments_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE reviews (
    id         INT UNSIGNED PRIMARY KEY,
    user_id    INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    order_id   INT UNSIGNED NOT NULL,
    rating     TINYINT NOT NULL,
    content    VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL,
    KEY idx_reviews_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE coupons (
    id         INT UNSIGNED PRIMARY KEY,
    code       VARCHAR(32) NOT NULL UNIQUE,
    discount   DECIMAL(8,2) NOT NULL,
    min_amount DECIMAL(10,2) NOT NULL,
    expires_at DATE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_coupons (
    id        INT UNSIGNED PRIMARY KEY,
    user_id   INT UNSIGNED NOT NULL,
    coupon_id INT UNSIGNED NOT NULL,
    used_at   DATETIME NULL,
    KEY idx_uc_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE audit_logs (
    id         INT UNSIGNED PRIMARY KEY,
    actor      VARCHAR(32) NOT NULL,
    action     VARCHAR(32) NOT NULL,
    detail     VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL,
    KEY idx_audit_actor (actor),
    KEY idx_audit_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
