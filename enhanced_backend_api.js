// 增强的后端API - 支持完整的客户和节点管理
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const Docker = require('dockerode');
const QRCode = require('qrcode');
const crypto = require('crypto');

const router = express.Router();
const docker = new Docker();

// 数据库连接
const db = new sqlite3.Database('./data/enhanced-xray-converter.db');

// 客户管理API
router.get('/api/customers', async (req, res) => {
    const { search, status, page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;
    
    let query = `
        SELECT c.*, 
               COUNT(cs.id) as service_count
        FROM customers c
        LEFT JOIN customer_services cs ON c.id = cs.customer_id AND cs.status = 'active'
    `;
    
    const params = [];
    const conditions = [];
    
    if (search) {
        conditions.push('(c.wechat_id LIKE ? OR c.wechat_name LIKE ? OR c.phone LIKE ?)');
        params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }
    
    if (status) {
        conditions.push('c.status = ?');
        params.push(status);
    }
    
    if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
    }
    
    query += ' GROUP BY c.id ORDER BY c.created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);
    
    db.all(query, params, (err, customers) => {
        if (err) {
            return res.status(500).json({ error: '数据库查询失败' });
        }
        res.json(customers);
    });
});

router.post('/api/customers', async (req, res) => {
    const { wechat_id, wechat_name, phone, email, status = 'active', notes } = req.body;
    
    // 验证必填字段
    if (!wechat_id || !wechat_name) {
        return res.status(400).json({ error: '微信号和微信名称为必填项' });
    }
    
    // 检查微信号是否已存在
    db.get('SELECT id FROM customers WHERE wechat_id = ?', [wechat_id], (err, existing) => {
        if (err) {
            return res.status(500).json({ error: '数据库查询失败' });
        }
        
        if (existing) {
            return res.status(400).json({ error: '该微信号已存在' });
        }
        
        // 创建客户
        db.run(
            'INSERT INTO customers (wechat_id, wechat_name, phone, email, status, notes) VALUES (?, ?, ?, ?, ?, ?)',
            [wechat_id, wechat_name, phone, email, status, notes],
            function(err) {
                if (err) {
                    return res.status(500).json({ error: '客户创建失败' });
                }
                
                res.status(201).json({
                    id: this.lastID,
                    wechat_id,
                    wechat_name,
                    phone,
                    email,
                    status,
                    notes,
                    message: '客户创建成功'
                });
            }
        );
    });
});

// 节点管理API
router.get('/api/nodes', async (req, res) => {
    const { region_id, status } = req.query;
    
    let query = `
        SELECT sn.*, r.name as region_name, r.code as region_code, r.flag_emoji,
               json_object('id', r.id, 'name', r.name, 'code', r.code, 'flag_emoji', r.flag_emoji) as region
        FROM socks5_nodes sn
        LEFT JOIN regions r ON sn.region_id = r.id
    `;
    
    const params = [];
    const conditions = [];
    
    if (region_id) {
        conditions.push('sn.region_id = ?');
        params.push(region_id);
    }
    
    if (status) {
        conditions.push('sn.status = ?');
        params.push(status);
    }
    
    if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
    }
    
    query += ' ORDER BY sn.created_at DESC';
    
    db.all(query, params, (err, nodes) => {
        if (err) {
            return res.status(500).json({ error: '数据库查询失败' });
        }
        
        // 解析region JSON
        const processedNodes = nodes.map(node => ({
            ...node,
            region: node.region ? JSON.parse(node.region) : null
        }));
        
        res.json(processedNodes);
    });
});

router.post('/api/nodes', async (req, res) => {
    const {
        node_name, socks5_number, region_id, ip_address, port,
        username, password, max_connections = 1, bandwidth_limit,
        expires_at, notes
    } = req.body;
    
    // 验证必填字段
    if (!node_name || !socks5_number || !region_id || !ip_address || !port) {
        return res.status(400).json({ error: '节点名称、编号、地区、IP地址和端口为必填项' });
    }
    
    // 验证端口范围
    if (port < 1 || port > 65535) {
        return res.status(400).json({ error: '端口号必须在1-65535之间' });
    }
    
    // 检查SOCKS5编号是否已存在
    db.get('SELECT id FROM socks5_nodes WHERE socks5_number = ?', [socks5_number], (err, existing) => {
        if (err) {
            return res.status(500).json({ error: '数据库查询失败' });
        }
        
        if (existing) {
            return res.status(400).json({ error: '该SOCKS5编号已存在' });
        }
        
        // 创建节点
        db.run(
            `INSERT INTO socks5_nodes 
             (node_name, socks5_number, region_id, ip_address, port, username, password, 
              max_connections, bandwidth_limit, expires_at, notes) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [node_name, socks5_number, region_id, ip_address, port, username, password,
             max_connections, bandwidth_limit, expires_at, notes],
            function(err) {
                if (err) {
                    return res.status(500).json({ error: '节点创建失败' });
                }
                
                res.status(201).json({
                    id: this.lastID,
                    node_name,
                    socks5_number,
                    region_id,
                    ip_address,
                    port,
                    max_connections,
                    message: '节点创建成功'
                });
            }
        );
    });
});

// 增强的服务管理API
router.get('/api/services/enhanced', async (req, res) => {
    const { customer_id, node_id, status, page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;
    
    let query = `
        SELECT 
            ss.*,
            json_object(
                'id', c.id, 
                'wechat_id', c.wechat_id, 
                'wechat_name', c.wechat_name,
                'status', c.status
            ) as customer,
            json_object(
                'id', sn.id,
                'node_name', sn.node_name,
                'socks5_number', sn.socks5_number,
                'ip_address', sn.ip_address,
                'port', sn.port,
                'username', sn.username,
                'password', sn.password,
                'current_connections', sn.current_connections,
                'max_connections', sn.max_connections,
                'region', json_object(
                    'id', r.id,
                    'name', r.name,
                    'code', r.code,
                    'flag_emoji', r.flag_emoji
                )
            ) as node
        FROM shadowsocks_services ss
        LEFT JOIN customers c ON ss.customer_id = c.id
        LEFT JOIN socks5_nodes sn ON ss.socks5_node_id = sn.id
        LEFT JOIN regions r ON sn.region_id = r.id
    `;
    
    const params = [];
    const conditions = [];
    
    if (customer_id) {
        conditions.push('ss.customer_id = ?');
        params.push(customer_id);
    }
    
    if (node_id) {
        conditions.push('ss.socks5_node_id = ?');
        params.push(node_id);
    }
    
    if (status) {
        conditions.push('ss.status = ?');
        params.push(status);
    }
    
    if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
    }
    
    query += ' ORDER BY ss.created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);
    
    db.all(query, params, (err, services) => {
        if (err) {
            return res.status(500).json({ error: '数据库查询失败' });
        }
        
        // 解析JSON字段
        const processedServices = services.map(service => ({
            ...service,
            customer: service.customer ? JSON.parse(service.customer) : null,
            node: service.node ? JSON.parse(service.node) : null
        }));
        
        res.json(processedServices);
    });
});

router.post('/api/services/enhanced', async (req, res) => {
    const {
        service_name, port, password, method = 'aes-256-gcm',
        socks5_node_id, customer_id, expires_at
    } = req.body;
    
    // 验证必填字段
    if (!port || !password || !socks5_node_id) {
        return res.status(400).json({ error: '端口、密码和SOCKS5节点为必填项' });
    }
    
    // 验证端口
    if (port < 1 || port > 65535) {
        return res.status(400).json({ error: '端口号必须在1-65535之间' });
    }
    
    // 检查端口是否已被使用
    db.get('SELECT id FROM shadowsocks_services WHERE port = ?', [port], async (err, existing) => {
        if (err) {
            return res.status(500).json({ error: '数据库查询失败' });
        }
        
        if (existing) {
            return res.status(400).json({ error: '该端口已被使用' });
        }
        
        // 检查节点是否可用
        db.get(
            'SELECT * FROM socks5_nodes WHERE id = ? AND status = "active" AND current_connections < max_connections',
            [socks5_node_id],
            async (err, node) => {
                if (err) {
                    return res.status(500).json({ error: '数据库查询失败' });
                }
                
                if (!node) {
                    return res.status(400).json({ error: '选择的节点不可用或已达到最大连接数' });
                }
                
                try {
                    // 生成Shadowsocks配置
                    const ssConfig = {
                        inbounds: [{
                            port: port,
                            protocol: 'shadowsocks',
                            settings: {
                                method: method,
                                password: password,
                                network: 'tcp,udp'
                            },
                            tag: 'ss-in'
                        }],
                        outbounds: [{
                            protocol: 'socks',
                            settings: {
                                servers: [{
                                    address: node.ip_address,
                                    port: node.port,
                                    ...(node.username && node.password ? {
                                        users: [{
                                            user: node.username,
                                            pass: node.password
                                        }]
                                    } : {})
                                }]
                            },
                            tag: 'socks-out'
                        }],
                        routing: {
                            rules: [{
                                type: 'field',
                                inboundTag: ['ss-in'],
                                outboundTag: 'socks-out'
                            }]
                        }
                    };
                    
                    // 生成SS链接
                    const ssLink = generateSSLink(method, password, '0.0.0.0', port, service_name);
                    
                    // 生成二维码
                    const qrCode = await QRCode.toDataURL(ssLink);
                    
                    // 启动Docker容器
                    const containerName = `xray-converter-${port}`;
                    const container = await docker.createContainer({
                        Image: 'teddysun/xray',
                        name: containerName,
                        ExposedPorts: {
                            [`${port}/tcp`]: {},
                            [`${port}/udp`]: {}
                        },
                        HostConfig: {
                            PortBindings: {
                                [`${port}/tcp`]: [{ HostPort: port.toString() }],
                                [`${port}/udp`]: [{ HostPort: port.toString() }]
                            },
                            RestartPolicy: { Name: 'unless-stopped' }
                        },
                        Env: [`XRAY_CONFIG=${JSON.stringify(ssConfig)}`]
                    });
                    
                    await container.start();
                    
                    // 保存到数据库
                    db.run(
                        `INSERT INTO shadowsocks_services 
                         (port, password, method, socks5_node_id, customer_id, service_name, 
                          qr_code, ss_link, expires_at, docker_container_name) 
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                        [port, password, method, socks5_node_id, customer_id, service_name,
                         qrCode, ssLink, expires_at, containerName],
                        function(err) {
                            if (err) {
                                return res.status(500).json({ error: '服务保存失败' });
                            }
                            
                            // 如果分配了客户，创建客户服务关联
                            if (customer_id) {
                                db.run(
                                    'INSERT INTO customer_services (customer_id, service_id, expires_at) VALUES (?, ?, ?)',
                                    [customer_id, this.lastID, expires_at]
                                );
                            }
                            
                            res.status(201).json({
                                id: this.lastID,
                                port,
                                service_name,
                                ss_link: ssLink,
                                qr_code: qrCode,
                                message: '服务创建成功'
                            });
                        }
                    );
                    
                } catch (dockerErr) {
                    console.error('Docker error:', dockerErr);
                    res.status(500).json({ error: 'Docker容器创建失败' });
                }
            }
        );
    });
});

// 地区管理API
router.get('/api/regions', (req, res) => {
    db.all(
        'SELECT * FROM regions WHERE status = "active" ORDER BY sort_order, name',
        (err, regions) => {
            if (err) {
                return res.status(500).json({ error: '数据库查询失败' });
            }
            res.json(regions);
        }
    );
});

// 工具函数
function generateSSLink(method, password, server, port, name) {
    const userInfo = Buffer.from(`${method}:${password}`).toString('base64');
    const serverInfo = `${server}:${port}`;
    const fragment = name ? `#${encodeURIComponent(name)}` : '';
    return `ss://${userInfo}@${serverInfo}${fragment}`;
}

module.exports = router;
