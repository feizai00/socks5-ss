-- Xray SOCKS5 转换器 - 增强数据库结构设计
-- 支持客户管理、节点管理、服务关联等完整功能

-- 1. 用户表 (系统管理员)
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    email TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- 2. 客户表
CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    wechat_id TEXT UNIQUE NOT NULL,           -- 客户微信号
    wechat_name TEXT NOT NULL,                -- 客户微信名称
    phone TEXT,                               -- 客户电话
    email TEXT,                               -- 客户邮箱
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'expired')),
    notes TEXT,                               -- 备注信息
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- 3. 地区表
CREATE TABLE IF NOT EXISTS regions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,                -- 地区名称 (如: 香港, 美国, 日本)
    code TEXT UNIQUE NOT NULL,                -- 地区代码 (如: HK, US, JP)
    flag_emoji TEXT,                          -- 地区旗帜表情
    sort_order INTEGER DEFAULT 0,            -- 排序权重
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- 4. SOCKS5节点表
CREATE TABLE IF NOT EXISTS socks5_nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_name TEXT NOT NULL,                  -- 节点名称
    socks5_number TEXT UNIQUE NOT NULL,       -- SOCKS5编号
    region_id INTEGER NOT NULL,              -- 地区ID
    ip_address TEXT NOT NULL,                -- SOCKS5 IP地址
    port INTEGER NOT NULL,                   -- SOCKS5 端口
    username TEXT,                           -- SOCKS5 用户名
    password TEXT,                           -- SOCKS5 密码
    max_connections INTEGER DEFAULT 1,       -- 最大连接数
    current_connections INTEGER DEFAULT 0,   -- 当前连接数
    bandwidth_limit INTEGER,                 -- 带宽限制 (Mbps)
    expires_at INTEGER,                      -- SOCKS5到期时间
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired', 'maintenance')),
    notes TEXT,                              -- 备注
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (region_id) REFERENCES regions(id)
);

-- 5. Shadowsocks服务表 (重新设计)
CREATE TABLE IF NOT EXISTS shadowsocks_services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    port INTEGER UNIQUE NOT NULL,            -- SS端口
    password TEXT NOT NULL,                  -- SS密码
    method TEXT DEFAULT 'aes-256-gcm',       -- 加密方法
    socks5_node_id INTEGER NOT NULL,         -- 关联的SOCKS5节点
    customer_id INTEGER,                     -- 关联的客户 (可为空，表示未分配)
    service_name TEXT,                       -- 服务名称
    qr_code TEXT,                           -- 二维码内容
    ss_link TEXT,                           -- SS链接
    expires_at INTEGER,                     -- 客户到期时间
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired', 'suspended')),
    docker_container_name TEXT,             -- Docker容器名称
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (socks5_node_id) REFERENCES socks5_nodes(id),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- 6. 客户服务关联表 (支持一个客户多个服务)
CREATE TABLE IF NOT EXISTS customer_services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    assigned_at INTEGER DEFAULT (strftime('%s', 'now')),
    expires_at INTEGER,                      -- 该客户对此服务的到期时间
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'suspended')),
    notes TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES shadowsocks_services(id) ON DELETE CASCADE,
    UNIQUE(customer_id, service_id)
);

-- 7. 操作日志表 (增强)
CREATE TABLE IF NOT EXISTS operation_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action TEXT NOT NULL,                    -- 操作类型
    target_type TEXT NOT NULL,               -- 目标类型 (customer, service, node, etc.)
    target_id INTEGER,                       -- 目标ID
    target_name TEXT,                        -- 目标名称
    details TEXT,                            -- 详细信息 (JSON格式)
    ip_address TEXT,                         -- 操作IP
    user_agent TEXT,                         -- 用户代理
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 8. 系统配置表
CREATE TABLE IF NOT EXISTS system_configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key TEXT UNIQUE NOT NULL,
    config_value TEXT,
    config_type TEXT DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- 9. 统计数据表
CREATE TABLE IF NOT EXISTS statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stat_date DATE NOT NULL,                 -- 统计日期
    total_customers INTEGER DEFAULT 0,       -- 总客户数
    active_customers INTEGER DEFAULT 0,      -- 活跃客户数
    total_services INTEGER DEFAULT 0,        -- 总服务数
    active_services INTEGER DEFAULT 0,       -- 活跃服务数
    total_nodes INTEGER DEFAULT 0,           -- 总节点数
    active_nodes INTEGER DEFAULT 0,          -- 活跃节点数
    bandwidth_usage REAL DEFAULT 0,          -- 带宽使用量 (GB)
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    UNIQUE(stat_date)
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_customers_wechat_id ON customers(wechat_id);
CREATE INDEX IF NOT EXISTS idx_customers_status ON customers(status);
CREATE INDEX IF NOT EXISTS idx_socks5_nodes_region ON socks5_nodes(region_id);
CREATE INDEX IF NOT EXISTS idx_socks5_nodes_status ON socks5_nodes(status);
CREATE INDEX IF NOT EXISTS idx_socks5_nodes_expires ON socks5_nodes(expires_at);
CREATE INDEX IF NOT EXISTS idx_services_customer ON shadowsocks_services(customer_id);
CREATE INDEX IF NOT EXISTS idx_services_node ON shadowsocks_services(socks5_node_id);
CREATE INDEX IF NOT EXISTS idx_services_status ON shadowsocks_services(status);
CREATE INDEX IF NOT EXISTS idx_services_expires ON shadowsocks_services(expires_at);
CREATE INDEX IF NOT EXISTS idx_customer_services_customer ON customer_services(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_services_service ON customer_services(service_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_user ON operation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_target ON operation_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_created ON operation_logs(created_at);

-- 插入默认数据
INSERT OR IGNORE INTO regions (name, code, flag_emoji, sort_order) VALUES
('香港', 'HK', '🇭🇰', 1),
('美国', 'US', '🇺🇸', 2),
('日本', 'JP', '🇯🇵', 3),
('新加坡', 'SG', '🇸🇬', 4),
('英国', 'GB', '🇬🇧', 5),
('德国', 'DE', '🇩🇪', 6),
('加拿大', 'CA', '🇨🇦', 7),
('澳大利亚', 'AU', '🇦🇺', 8),
('韩国', 'KR', '🇰🇷', 9),
('台湾', 'TW', '🇹🇼', 10);

INSERT OR IGNORE INTO system_configs (config_key, config_value, config_type, description) VALUES
('default_ss_method', 'aes-256-gcm', 'string', '默认Shadowsocks加密方法'),
('default_service_duration', '30', 'number', '默认服务有效期(天)'),
('max_services_per_customer', '5', 'number', '每个客户最大服务数量'),
('auto_cleanup_expired', 'true', 'boolean', '自动清理过期服务'),
('backup_retention_days', '30', 'number', '备份保留天数'),
('log_retention_days', '90', 'number', '日志保留天数');

-- 创建视图以简化查询
CREATE VIEW IF NOT EXISTS service_overview AS
SELECT 
    ss.id,
    ss.port,
    ss.password,
    ss.method,
    ss.service_name,
    ss.status as service_status,
    ss.expires_at as service_expires_at,
    ss.docker_container_name,
    c.id as customer_id,
    c.wechat_id,
    c.wechat_name,
    sn.id as node_id,
    sn.node_name,
    sn.socks5_number,
    sn.ip_address as socks5_ip,
    sn.port as socks5_port,
    sn.username as socks5_username,
    sn.password as socks5_password,
    sn.expires_at as socks5_expires_at,
    r.name as region_name,
    r.code as region_code,
    r.flag_emoji,
    (SELECT COUNT(*) FROM customer_services cs WHERE cs.customer_id = c.id AND cs.status = 'active') as customer_service_count
FROM shadowsocks_services ss
LEFT JOIN customers c ON ss.customer_id = c.id
LEFT JOIN socks5_nodes sn ON ss.socks5_node_id = sn.id
LEFT JOIN regions r ON sn.region_id = r.id;

-- 创建触发器以自动更新时间戳
CREATE TRIGGER IF NOT EXISTS update_customers_timestamp 
    AFTER UPDATE ON customers
BEGIN
    UPDATE customers SET updated_at = strftime('%s', 'now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_socks5_nodes_timestamp 
    AFTER UPDATE ON socks5_nodes
BEGIN
    UPDATE socks5_nodes SET updated_at = strftime('%s', 'now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_shadowsocks_services_timestamp 
    AFTER UPDATE ON shadowsocks_services
BEGIN
    UPDATE shadowsocks_services SET updated_at = strftime('%s', 'now') WHERE id = NEW.id;
END;

-- 创建触发器以自动更新节点连接数
CREATE TRIGGER IF NOT EXISTS update_node_connections_on_service_create
    AFTER INSERT ON shadowsocks_services
    WHEN NEW.status = 'active'
BEGIN
    UPDATE socks5_nodes 
    SET current_connections = current_connections + 1 
    WHERE id = NEW.socks5_node_id;
END;

CREATE TRIGGER IF NOT EXISTS update_node_connections_on_service_delete
    AFTER DELETE ON shadowsocks_services
BEGIN
    UPDATE socks5_nodes 
    SET current_connections = CASE 
        WHEN current_connections > 0 THEN current_connections - 1 
        ELSE 0 
    END 
    WHERE id = OLD.socks5_node_id;
END;

CREATE TRIGGER IF NOT EXISTS update_node_connections_on_service_status_change
    AFTER UPDATE OF status ON shadowsocks_services
    WHEN OLD.status != NEW.status
BEGIN
    UPDATE socks5_nodes 
    SET current_connections = (
        SELECT COUNT(*) 
        FROM shadowsocks_services 
        WHERE socks5_node_id = NEW.socks5_node_id AND status = 'active'
    )
    WHERE id = NEW.socks5_node_id;
END;
